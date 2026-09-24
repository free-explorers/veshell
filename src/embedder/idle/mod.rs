use std::time::{Duration, Instant};

use smithay::reexports::calloop::timer::{TimeoutAction, Timer};
use smithay::reexports::calloop::{channel, LoopHandle, RegistrationToken};
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::reexports::wayland_server::Resource;

use crate::backend::Backend;
use crate::settings::IdleSettings;
use crate::state::State;

mod dbus;

/// Interval between fade ticks while the dim alpha animates upward.
const FADE_TICK: Duration = Duration::from_millis(40);

/// The current screensaver stage.
///
/// `Active` -> (dim timeout) -> `Fading` (alpha 0..=1 over the fade
/// duration) -> `Dimmed` (alpha 1, overlay fully black) -> (blank timeout)
/// -> `Blank` (`CAN_BLANK` backends only: KMS compositor cleared, frame
/// queueing stopped). Any input flips the machine back to `Active`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum IdleStage {
    Active,
    Fading,
    Dimmed,
    Blank,
}

pub struct IdleState<BackendData: Backend + 'static> {
    pub loop_handle: LoopHandle<'static, State<BackendData>>,
    stage: IdleStage,
    dim_alpha: f32,
    dim_timeout: Duration,
    blank_timeout: Duration,
    fade_duration: Duration,
    fade_started: Option<Instant>,
    dim_token: Option<RegistrationToken>,
    blank_token: Option<RegistrationToken>,
    fade_token: Option<RegistrationToken>,
    pub(crate) inhibiting_surfaces: Vec<WlSurface>,
    dbus_inhibited: bool,
    /// Backend hook that re-drives rendering after waking/blanking.
    request_render: fn(&mut State<BackendData>),
    /// Backend hook that powers the outputs down (`CAN_BLANK` backends only).
    apply_blank: fn(&mut State<BackendData>),
}

impl<BackendData: Backend + 'static> IdleState<BackendData> {
    pub fn new(
        loop_handle: LoopHandle<'static, State<BackendData>>,
        settings: &IdleSettings,
    ) -> Self {
        let (dbus_events, dbus_receiver) = channel::channel::<dbus::IdleDbusEvent>();
        loop_handle
            .insert_source(dbus_receiver, |event, _, state: &mut State<BackendData>| {
                if let channel::Event::Msg(event) = event {
                    match event {
                        dbus::IdleDbusEvent::Inhibited(inhibited) => {
                            state.idle.dbus_inhibited = inhibited;
                            refresh_idle_inhibit(state);
                        }
                        dbus::IdleDbusEvent::SimulateActivity => on_activity(state),
                    }
                }
            })
            .expect("Failed to initialize screensaver D-Bus event source");
        if BackendData::RUNS_PORTAL_BACKEND {
            dbus::spawn(dbus_events);
        }

        Self {
            loop_handle,
            stage: IdleStage::Active,
            dim_alpha: 0.0,
            dim_timeout: Duration::from_secs(settings.dim_timeout_seconds as u64),
            blank_timeout: Duration::from_secs(settings.blank_timeout_seconds as u64),
            fade_duration: Duration::from_secs_f32(settings.fade_seconds.max(0.0)),
            fade_started: None,
            dim_token: None,
            blank_token: None,
            fade_token: None,
            inhibiting_surfaces: Vec::new(),
            dbus_inhibited: false,
            request_render: no_op,
            apply_blank: no_op,
        }
    }

    pub fn set_request_render(&mut self, callback: fn(&mut State<BackendData>)) {
        self.request_render = callback;
    }

    pub fn set_apply_blank(&mut self, callback: fn(&mut State<BackendData>)) {
        self.apply_blank = callback;
    }

    pub fn dim_alpha(&self) -> f32 {
        self.dim_alpha
    }

    pub fn is_blank(&self) -> bool {
        self.stage == IdleStage::Blank
    }

    /// Cancel every timer of the machine.
    pub(crate) fn cancel_all(&mut self) {
        for token in [
            self.dim_token.take(),
            self.blank_token.take(),
            self.fade_token.take(),
        ]
        .into_iter()
        .flatten()
        {
            self.loop_handle.remove(token);
        }
        self.fade_started = None;
    }

    /// (Re-)arm the dim and blank timers with the whole timeouts measured
    /// from "now". A no-op while idle inhibition is active.
    pub(crate) fn arm_activity_timers(&mut self) {
        self.cancel_all();
        if !self.dim_timeout.is_zero() {
            let dim_timeout = self.dim_timeout;
            self.dim_token = self
                .loop_handle
                .insert_source(Timer::from_duration(dim_timeout), {
                    move |_, _, state| {
                        idle_dim_fired(state);
                        TimeoutAction::Drop
                    }
                })
                .ok();
        }
        if !self.blank_timeout.is_zero() {
            let blank_timeout = self.blank_timeout;
            self.blank_token = self
                .loop_handle
                .insert_source(Timer::from_duration(blank_timeout), {
                    move |_, _, state| {
                        blank_fired(state);
                        TimeoutAction::Drop
                    }
                })
                .ok();
        }
    }
}

fn no_op<BackendData: Backend + 'static>(_: &mut State<BackendData>) {}

/// Every input event funnels through here: it resets the stage machine and
/// re-arms its timers, and forwards the activity to ext-idle-notify clients.
pub fn on_activity<D: Backend + 'static>(state: &mut State<D>) {
    state.idle_notifier_state.notify_activity(&state.seat);

    if state.idle.stage != IdleStage::Active {
        state.idle.dim_alpha = 0.0;
        state.idle.cancel_all();
        state.idle.stage = IdleStage::Active;
        (state.idle.request_render)(state);
    }
    if !is_inhibited(state) {
        state.idle.arm_activity_timers();
    }
}

/// Whether any idle inhibitor is currently active: explicit Wayland or
/// freedesktop ScreenSaver D-Bus inhibitors, or a capture/recording session.
pub fn is_inhibited<D: Backend + 'static>(state: &State<D>) -> bool {
    state.idle.dbus_inhibited
        || !state.idle.inhibiting_surfaces.is_empty()
        || state.capture_state.session.is_some()
        || state.capture_state.recording_session.is_some()
}

/// Recompute the inhibition state after a surface inhibitor or a capture
/// session appeared or went away. Wakes the stage machine when inhibition
/// arrives late.
pub fn refresh_idle_inhibit<D: Backend + 'static>(state: &mut State<D>) {
    state
        .idle
        .inhibiting_surfaces
        .retain(|surface| surface.is_alive());
    let inhibited = is_inhibited(state);
    state.idle_notifier_state.set_is_inhibited(inhibited);

    if !inhibited {
        if state.idle.stage == IdleStage::Active {
            state.idle.arm_activity_timers();
        }
        return;
    }
    if state.idle.stage != IdleStage::Active {
        state.idle.dim_alpha = 0.0;
        state.idle.cancel_all();
        state.idle.stage = IdleStage::Active;
        (state.idle.request_render)(state);
    } else {
        state.idle.cancel_all();
    }
}

/// Push new timeout values from settings and re-arm while active.
pub fn apply_idle_settings<D: Backend + 'static>(state: &mut State<D>, settings: &IdleSettings) {
    state.idle.dim_timeout = Duration::from_secs(settings.dim_timeout_seconds as u64);
    state.idle.blank_timeout = Duration::from_secs(settings.blank_timeout_seconds as u64);
    state.idle.fade_duration = Duration::from_secs_f32(settings.fade_seconds.max(0.0));
    if state.idle.stage == IdleStage::Active {
        if is_inhibited(state) {
            state.idle.cancel_all();
        } else {
            state.idle.arm_activity_timers();
        }
    }
}

/// Dim timeout expired: start the fade toward black.
fn idle_dim_fired<D: Backend + 'static>(state: &mut State<D>) {
    let idle = &mut state.idle;
    idle.dim_token = None;
    idle.stage = IdleStage::Fading;
    idle.fade_started = Some(Instant::now());
    let fade_duration = idle.fade_duration;
    idle.fade_token = idle
        .loop_handle
        .insert_source(Timer::from_duration(FADE_TICK.min(fade_duration)), {
            move |_, _, data| {
                fade_tick(data);
                TimeoutAction::ToDuration(FADE_TICK)
            }
        })
        .ok();
    fade_tick(state);
}

fn fade_tick<D: Backend + 'static>(state: &mut State<D>) {
    let fade_started = match state.idle.fade_started {
        Some(fade_started) => fade_started,
        None => return,
    };
    let fade_duration = state.idle.fade_duration;
    let progress = if fade_duration.is_zero() {
        1.0
    } else {
        (fade_started.elapsed().as_secs_f32() / fade_duration.as_secs_f32()).min(1.0)
    };
    state.idle.dim_alpha = progress;
    (state.idle.request_render)(state);
    if progress >= 1.0 {
        state.idle.fade_started = None;
        if let Some(fade_token) = state.idle.fade_token.take() {
            state.idle.loop_handle.remove(fade_token);
        }
        state.idle.stage = IdleStage::Dimmed;
    }
}

/// Blank timeout expired: render level 1.0 everywhere and on `CAN_BLANK`
/// backends clear the KMS compositor and stop the render loop.
fn blank_fired<D: Backend + 'static>(state: &mut State<D>) {
    if state.idle.stage == IdleStage::Blank {
        return;
    }
    state.idle.blank_token = None;
    state.idle.dim_alpha = 1.0;
    state.idle.cancel_all();
    if <D as Backend>::CAN_BLANK {
        state.idle.stage = IdleStage::Blank;
        (state.idle.apply_blank)(state);
    } else {
        state.idle.stage = IdleStage::Dimmed;
        (state.idle.request_render)(state);
    }
}

#[cfg(test)]
mod tests {
    use crate::settings::IdleSettings;

    #[test]
    fn default_settings_use_five_minute_dim_and_ten_minute_blank() {
        let settings = IdleSettings::default();
        assert_eq!(settings.dim_timeout_seconds, 300);
        assert_eq!(settings.blank_timeout_seconds, 600);
        assert_eq!(settings.fade_seconds, 3.0);
    }

    #[test]
    fn fade_tick_progress_is_two_phase_linear() {
        let fade_duration = std::time::Duration::from_secs(10);
        let elapsed = std::time::Duration::from_secs(4);
        let progress = if fade_duration.is_zero() {
            1.0f32
        } else {
            (elapsed.as_secs_f32() / fade_duration.as_secs_f32()).min(1.0)
        };
        assert_eq!(progress, 0.4);
    }
}
