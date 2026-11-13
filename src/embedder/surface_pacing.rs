//! Frame pacing of client surfaces by what the shell displays.
//!
//! The shell draws client windows through Flutter, so the compositor cannot
//! tell from its own render which surfaces are on screen. The shell reports
//! them (`surface_visibility`) and every client surface gets a pace:
//!
//! - **full**: frame callbacks every vsync tick. Surfaces painted on screen,
//!   plus the ones that must stay live whatever the shell shows: popups, the
//!   keyboard and pointer focus, and windows shared through a screen cast.
//! - **hidden** ([`HIDDEN_INTERVAL`]): everything else. Like niri, a hidden
//!   surface still gets a frame callback about once a second, so a client
//!   blocked on one never stalls completely.
//!
//! Until the shell's first report every surface is full.

use std::collections::HashSet;
use std::time::{Duration, Instant};

use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::wayland::compositor::with_states;
use smithay::wayland::seat::WaylandFocus;
use std::cell::{Cell, RefCell};

use crate::wayland::wayland::WlSurfaceVeshellState;
use crate::{send_frames_surface_tree, Backend, State};

/// Frame interval of a hidden surface: about once a second, as in niri.
pub const HIDDEN_INTERVAL: Duration = Duration::from_secs(1);

/// Ticks follow the refresh, so an interval rarely ends exactly on one: a tick
/// that lands this close before the interval ends counts, instead of waiting a
/// whole refresh more.
const TICK_TOLERANCE: Duration = Duration::from_millis(2);

/// How often a surface receives frame callbacks.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Pace {
    Full,
    Hidden,
}

impl Pace {
    fn interval(self) -> Option<Duration> {
        match self {
            Pace::Full => None,
            Pace::Hidden => Some(HIDDEN_INTERVAL),
        }
    }
}

/// The shell's latest report.
struct Report {
    visible: HashSet<u64>,
}

#[derive(Default)]
pub struct SurfacePacing {
    /// `None` until the shell's first report: every surface is full.
    report: Option<Report>,
}

/// When a surface last received its frame callbacks.
#[derive(Default)]
struct LastFrameCallback(Cell<Option<Instant>>);

fn surface_id_of(surface: &WlSurface) -> Option<u64> {
    with_states(surface, |states| {
        states
            .data_map
            .get::<RefCell<WlSurfaceVeshellState>>()
            .map(|state| state.borrow().surface_id)
    })
}

/// Whether `surface` is due for a frame callback at `pace`, recording the send
/// when it is.
fn take_due(surface: &WlSurface, pace: Pace, now: Instant) -> bool {
    with_states(surface, |states| {
        let last = states.data_map.get_or_insert(LastFrameCallback::default);
        let due = match (pace.interval(), last.0.get()) {
            (None, _) | (_, None) => true,
            (Some(interval), Some(last)) => {
                now.saturating_duration_since(last) + TICK_TOLERANCE >= interval
            }
        };
        if due {
            last.0.set(Some(now));
        }
        due
    })
}

/// Forgets when `surface` last received a frame callback, so its next tick
/// sends one whatever its pace was.
fn reset_due(surface: &WlSurface) {
    with_states(surface, |states| {
        if let Some(last) = states.data_map.get::<LastFrameCallback>() {
            last.0.set(None);
        }
    });
}

impl<BackendData: Backend + 'static> State<BackendData> {
    /// Applies the shell's report of the surfaces it displays.
    ///
    /// A surface that became visible gets its next frame callback on the next
    /// tick instead of waiting out its old interval.
    pub fn set_surface_visibility(&mut self, visible: HashSet<u64>) {
        let previous = self.surface_pacing.report.replace(Report { visible });
        let report = self.surface_pacing.report.as_ref().unwrap();

        let woken: Vec<u64> = report
            .visible
            .iter()
            .filter(|id| {
                previous
                    .as_ref()
                    .is_none_or(|previous| !previous.visible.contains(id))
            })
            .copied()
            .collect();
        for id in woken {
            if let Some(surface) = self.surfaces.get(&id) {
                reset_due(surface);
            }
        }
    }

    /// The pace of the client surface `surface`.
    pub fn surface_pace(&self, surface: &WlSurface) -> Pace {
        let Some(report) = &self.surface_pacing.report else {
            return Pace::Full;
        };
        let Some(surface_id) = surface_id_of(surface) else {
            return Pace::Full;
        };
        if report.visible.contains(&surface_id)
            || self.surface_shared_or_gaming(surface_id)
            || self.surface_has_input_focus(surface)
        {
            return Pace::Full;
        }
        Pace::Hidden
    }

    /// Whether `surface` has the keyboard or pointer focus: a client the user
    /// interacts with keeps a full pace whatever the shell displays.
    fn surface_has_input_focus(&self, surface: &WlSurface) -> bool {
        let keyboard_focus = self
            .keyboard
            .current_focus()
            .and_then(|focus| focus.wl_surface().map(|s| s.into_owned()));
        if keyboard_focus.as_ref() == Some(surface) {
            return true;
        }
        let pointer_focus = self
            .pointer
            .current_focus()
            .and_then(|focus| focus.wl_surface().map(|s| s.into_owned()));
        pointer_focus.as_ref() == Some(surface)
    }

    /// Surfaces that keep a full pace whatever the shell displays: windows
    /// shared through a screen cast (a consumer watches them even when the
    /// shell does not), and the active game.
    fn surface_shared_or_gaming(&self, surface_id: u64) -> bool {
        // An active game is drawn by the compositor, not the shell (which
        // shows a placeholder in its place).
        let gaming = self
            .meta_window_state
            .meta_window_in_gaming_mode
            .as_ref()
            .and_then(|id| self.meta_window_state.meta_windows.get(id))
            .is_some_and(|window| window.surface_id == surface_id);
        gaming
            || self
                .portal_state
                .recording_targets
                .values()
                .flatten()
                .filter_map(|id| self.meta_window_state.meta_windows.get(id))
                .any(|window| window.surface_id == surface_id)
    }

    /// Sends the frame callbacks of the client surfaces the shell draws, each
    /// at its pace. `skip` lists surfaces paced elsewhere (game-mode surfaces
    /// follow their own output's vblank).
    ///
    /// Returns the surfaces that received callbacks, with whether they are
    /// shown: their presentation feedback is due with the callbacks.
    pub fn send_paced_frame_callbacks(&mut self, skip: &[WlSurface]) -> Vec<(WlSurface, bool)> {
        let now = Instant::now();
        let frame_timestamp = self.frame_timestamp_millis();

        let mut roots: Vec<(WlSurface, Pace)> = Vec::new();
        for toplevel in self.xdg_shell_state.toplevel_surfaces() {
            let surface = toplevel.wl_surface().clone();
            let pace = self.surface_pace(&surface);
            roots.push((surface, pace));
        }
        // A popup only exists while its menu is open: it stays live.
        for popup in self.xdg_popups.values() {
            roots.push((popup.wl_surface().clone(), Pace::Full));
        }
        for surface in self.x11_surface_per_wl_surface.keys() {
            roots.push((surface.clone(), self.surface_pace(surface)));
        }

        let mut sent = Vec::new();
        for (surface, pace) in roots {
            if skip.contains(&surface) || !take_due(&surface, pace, now) {
                continue;
            }
            send_frames_surface_tree(&surface, frame_timestamp);
            sent.push((surface, pace != Pace::Hidden));
        }
        sent
    }
}
