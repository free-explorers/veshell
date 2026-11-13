//! Frame pacing of client surfaces by what the shell displays.
//!
//! The shell draws client windows through Flutter, so the compositor cannot
//! tell from its own render which surfaces are on screen. The shell reports
//! them (`surface_visibility`) and every client surface gets a pace:
//!
//! - **full**: frame callbacks every vsync tick. Surfaces painted on screen,
//!   plus the ones that must stay live whatever the shell shows: popups, the
//!   keyboard and pointer focus, and windows shared through a screen cast.
//! - **limited** ([`LIMITED_INTERVAL`]): surfaces painted on screen that only
//!   need a low rate, a paused game behind its frost. Their commits are also
//!   held to that rate, so a client that does not wait for frame callbacks (a
//!   game with vsync off) runs out of free buffers and slows down too, and the
//!   shell only redraws them at that rate.
//! - **hidden** ([`HIDDEN_INTERVAL`]): everything else. Like niri, a hidden
//!   surface still gets a frame callback about once a second, so a client
//!   blocked on one never stalls completely.
//!
//! Until the shell's first report every surface is full.

use std::collections::{HashMap, HashSet};
use std::time::{Duration, Instant};

use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::reexports::wayland_server::{Client, Resource};
use smithay::wayland::compositor::{add_blocker, with_states, Barrier, CompositorHandler};
use smithay::wayland::seat::WaylandFocus;
use std::cell::{Cell, RefCell};

use crate::wayland::wayland::WlSurfaceVeshellState;
use crate::{send_frames_surface_tree, Backend, State};

/// Frame interval of a limited surface (15 fps).
pub const LIMITED_INTERVAL: Duration = Duration::from_nanos(1_000_000_000 / 15);

/// Frame interval of a hidden surface: about once a second, as in niri.
pub const HIDDEN_INTERVAL: Duration = Duration::from_secs(1);

/// Ticks follow the refresh, so an interval rarely ends exactly on one: a tick
/// that lands this close before the interval ends counts, instead of waiting a
/// whole refresh more (15 fps would otherwise come out at 12 on a 60 Hz panel).
const TICK_TOLERANCE: Duration = Duration::from_millis(2);

/// How often a surface receives frame callbacks.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Pace {
    Full,
    Limited,
    Hidden,
}

impl Pace {
    fn interval(self) -> Option<Duration> {
        match self {
            Pace::Full => None,
            Pace::Limited => Some(LIMITED_INTERVAL),
            Pace::Hidden => Some(HIDDEN_INTERVAL),
        }
    }
}

/// The shell's latest report.
struct Report {
    visible: HashSet<u64>,
    limited: HashSet<u64>,
}

#[derive(Default)]
pub struct SurfacePacing {
    /// `None` until the shell's first report: every surface is full.
    report: Option<Report>,
    /// Commits of limited surfaces held until the surface's next paced tick.
    held_commits: HashMap<u64, Vec<(Client, Barrier)>>,
    /// Limited surfaces with a committed texture the shell has not been told
    /// about yet, by surface id.
    pending_texture_marks: HashMap<u64, i64>,
}

impl SurfacePacing {
    /// Whether the surface with id `surface_id` is limited.
    pub fn is_limited(&self, surface_id: u64) -> bool {
        self.report
            .as_ref()
            .is_some_and(|report| report.limited.contains(&surface_id))
    }

    /// Holds a new frame of a limited surface until its next paced tick
    /// instead of telling the shell right away.
    pub fn defer_texture_mark(&mut self, surface_id: u64, texture_id: i64) {
        self.pending_texture_marks.insert(surface_id, texture_id);
    }
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
    /// tick instead of waiting out its old interval, and a surface that is no
    /// longer limited gets its held commits and frames released at once.
    pub fn set_surface_visibility(&mut self, visible: HashSet<u64>, limited: HashSet<u64>) {
        let previous = self
            .surface_pacing
            .report
            .replace(Report { visible, limited });
        let report = self.surface_pacing.report.as_ref().unwrap();

        let woken: Vec<u64> = report
            .visible
            .iter()
            .chain(report.limited.iter())
            .filter(|id| {
                previous
                    .as_ref()
                    .is_none_or(|previous| !previous.visible.contains(id))
            })
            .copied()
            .collect();
        let unlimited: Vec<u64> = self
            .surface_pacing
            .held_commits
            .keys()
            .chain(self.surface_pacing.pending_texture_marks.keys())
            .filter(|id| !report.limited.contains(id))
            .copied()
            .collect();

        for id in woken {
            if let Some(surface) = self.surfaces.get(&id) {
                reset_due(surface);
            }
        }
        for id in unlimited {
            self.release_limited_surface(id, false);
        }
    }

    /// Holds the commit `surface` is about to make when it is limited: the
    /// commit applies on the surface's next paced tick. Called from the
    /// pre-commit hook.
    pub fn hold_limited_commit(&mut self, surface: &WlSurface) {
        let Some(surface_id) = surface_id_of(surface) else {
            return;
        };
        // Only while it actually runs at the limited pace: a limited surface
        // kept live (under the pointer, say) gets a frame callback every tick,
        // and holding its commits there would freeze it.
        if !self.surface_pacing.is_limited(surface_id)
            || self.surface_pace(surface) != Pace::Limited
        {
            return;
        }
        let Some(client) = surface.client() else {
            return;
        };
        let barrier = Barrier::new(false);
        add_blocker(surface, barrier.clone());
        self.surface_pacing
            .held_commits
            .entry(surface_id)
            .or_default()
            .push((client, barrier));
    }

    /// Applies the commits held for a limited surface and tells the shell
    /// about its latest frame.
    ///
    /// `oldest_only` applies a single commit, the one held longest: on a
    /// limited tick a client that queued several frames since the last one
    /// (a game with vsync off fills every buffer it has) gets one frame
    /// through per tick, so the game itself runs at the limited rate instead
    /// of only being shown at it.
    fn release_limited_surface(&mut self, surface_id: u64, oldest_only: bool) {
        let held: Vec<(Client, Barrier)> =
            match self.surface_pacing.held_commits.get_mut(&surface_id) {
                Some(queue) if oldest_only && queue.len() > 1 => vec![queue.remove(0)],
                Some(_) => self
                    .surface_pacing
                    .held_commits
                    .remove(&surface_id)
                    .unwrap_or_default(),
                None => Vec::new(),
            };
        let display = self.display_handle.clone();
        for (client, barrier) in held {
            barrier.signal();
            self.client_compositor_state(&client)
                .blocker_cleared(self, &display);
        }
        if let Some(texture_id) = self
            .surface_pacing
            .pending_texture_marks
            .remove(&surface_id)
        {
            let _ = self
                .flutter_engine_mut()
                .mark_external_texture_frame_available(texture_id);
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
        if report.visible.contains(&surface_id) || self.surface_shared_or_gaming(surface_id) {
            return Pace::Full;
        }
        // A paused game takes no input: hovering its frosted tile must not
        // lift the limit.
        if report.limited.contains(&surface_id) {
            return Pace::Limited;
        }
        if self.surface_has_input_focus(surface) {
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
            // Apply the held commits before answering the frame callbacks they
            // carry: the oldest one on a limited tick, all of them at any other
            // pace (a held commit must never outlive the pace that held it).
            if let Some(surface_id) = surface_id_of(&surface) {
                self.release_limited_surface(surface_id, pace == Pace::Limited);
            }
            send_frames_surface_tree(&surface, frame_timestamp);
            sent.push((surface, pace != Pace::Hidden));
        }
        sent
    }
}
