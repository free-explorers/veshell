//! Night Light: warms the outputs' colour temperature at night.
//!
//! The compositor owns it, so it follows its schedule whatever the shell does,
//! and applies it in the outputs' colour lookup tables (see
//! [`crate::backend::Backend::set_color_gains`]): the tint costs nothing per
//! frame, covers every plane (cursor and directly scanned-out games included),
//! and stays out of screenshots and recordings.
//!
//! Night Light is on when the schedule says so, unless the user overrode it
//! from the Helm: turning it off during the scheduled window keeps it off
//! until the window ends, and turning it on outside the window keeps it on
//! until the window starts (after which the schedule keeps it on). The override
//! is in memory only. Without a schedule the toggle is the only switch, and it
//! holds until the compositor restarts.
//!
//! See `docs/specifications/night_light.md`.

use std::time::{Duration, Instant};

use chrono::{Local, Timelike};
use serde_json::json;
use smithay::reexports::calloop::timer::{TimeoutAction, Timer};
use smithay::reexports::calloop::RegistrationToken;

use crate::backend::Backend;
use crate::settings::{NightLightSchedule, NightLightSettings};
use crate::state::State;

pub mod schedule;
pub mod temperature;

/// How long a change of temperature takes to fade in.
const FADE_DURATION: Duration = Duration::from_secs(2);

/// How often the fade updates the lookup tables. Each update takes one of the
/// output's vblanks from rendering (see `crate::backend::gamma`): ten a second
/// keep the tint changing smoothly and leave the shell five frames in six.
const FADE_STEP: Duration = Duration::from_millis(100);

/// An in-progress change of temperature.
#[derive(Debug, Clone, Copy)]
struct Fade {
    from: f64,
    to: f64,
    started: Instant,
}

/// The Night Light state. The decisions are kept free of timers and of the
/// backend so they can be tested on their own; see [`apply_settings`],
/// [`set_enabled`] and the private timers for the side effects.
#[derive(Debug)]
pub struct NightLight {
    settings: NightLightSettings,
    /// The schedule's verdict when it was last evaluated.
    scheduled: bool,
    /// The user's Helm choice, until the schedule's next transition.
    user_override: Option<bool>,
    /// The temperature currently in the lookup tables, in kelvin.
    applied_kelvin: f64,
    fade: Option<Fade>,
    fade_token: Option<RegistrationToken>,
    schedule_token: Option<RegistrationToken>,
}

impl NightLight {
    /// Night Light as `settings` and the local time `minute` (after midnight)
    /// have it, already at its temperature: there is nothing to fade from at
    /// startup.
    pub fn new(settings: &NightLightSettings, minute: u16) -> Self {
        let mut night_light = Self {
            settings: *settings,
            scheduled: false,
            user_override: None,
            applied_kelvin: temperature::NEUTRAL_KELVIN,
            fade: None,
            fade_token: None,
            schedule_token: None,
        };
        night_light.scheduled = night_light.schedule_verdict(minute);
        night_light.applied_kelvin = night_light.target_kelvin();
        night_light
    }

    /// Whether Night Light is on (it may still be fading in or out).
    pub fn is_active(&self) -> bool {
        self.user_override.unwrap_or(self.scheduled)
    }

    /// The per-channel gains for the temperature currently applied.
    pub fn gains(&self) -> [f64; 3] {
        temperature::gains(self.applied_kelvin)
    }

    /// The temperature Night Light is heading to.
    fn target_kelvin(&self) -> f64 {
        if self.is_active() {
            f64::from(self.settings.temperature)
        } else {
            temperature::NEUTRAL_KELVIN
        }
    }

    fn schedule_verdict(&self, minute: u16) -> bool {
        match self.settings.schedule {
            NightLightSchedule::Off => false,
            NightLightSchedule::Manual => {
                schedule::in_window(self.settings.from, self.settings.to, minute)
            }
        }
    }

    /// Records the schedule's verdict at `minute`. A transition ends the
    /// user's override: from then on the schedule decides again.
    fn evaluate_schedule(&mut self, minute: u16) {
        let scheduled = self.schedule_verdict(minute);
        if scheduled != self.scheduled {
            self.scheduled = scheduled;
            self.user_override = None;
        }
    }

    /// The user's Helm choice. Choosing what the schedule already says clears
    /// the override instead of pinning it.
    fn set_user_choice(&mut self, enabled: bool) {
        self.user_override = (enabled != self.scheduled).then_some(enabled);
    }

    /// Adopts new settings, re-evaluating the schedule at `minute`.
    fn set_settings(&mut self, settings: &NightLightSettings, minute: u16) {
        let schedule_changed = settings.schedule != self.settings.schedule
            || settings.from != self.settings.from
            || settings.to != self.settings.to;
        self.settings = *settings;
        if schedule_changed {
            self.evaluate_schedule(minute);
        }
    }

    /// Starts fading toward the target, from where the tables are now.
    /// Returns whether there is anything to fade.
    fn retarget(&mut self, now: Instant) -> bool {
        let target = self.target_kelvin();
        let heading = self.fade.map_or(self.applied_kelvin, |fade| fade.to);
        if (heading - target).abs() < 0.5 {
            return self.fade.is_some();
        }
        self.fade = Some(Fade {
            from: self.applied_kelvin,
            to: target,
            started: now,
        });
        true
    }

    /// Advances the fade to `now`. Returns whether it is still running.
    fn step_fade(&mut self, now: Instant) -> bool {
        let Some(fade) = self.fade else {
            return false;
        };
        let progress =
            now.saturating_duration_since(fade.started).as_secs_f64() / FADE_DURATION.as_secs_f64();
        self.applied_kelvin = temperature::interpolate(fade.from, fade.to, progress);
        if progress >= 1.0 {
            self.applied_kelvin = fade.to;
            self.fade = None;
        }
        self.fade.is_some()
    }
}

/// The local time of day, in minutes after midnight.
pub fn local_minute() -> u16 {
    let now = Local::now();
    (now.hour() * 60 + now.minute()) as u16
}

/// How long until the next local minute starts, with a little slack so the
/// evaluation lands inside the new minute.
fn until_next_minute() -> Duration {
    let now = Local::now();
    let elapsed = Duration::from_secs(u64::from(now.second()))
        + Duration::from_nanos(u64::from(now.nanosecond().min(999_999_999)));
    Duration::from_secs(60).saturating_sub(elapsed) + Duration::from_millis(50)
}

/// Applies the startup settings: the tables get the current temperature, and
/// the schedule starts being followed. Called once the state exists.
pub fn init<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    let gains = state.night_light.gains();
    state.backend_data.set_color_gains(gains);
    sync_schedule_timer(state);
}

/// Adopts changed settings: a new schedule or temperature fades in.
pub fn apply_settings<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    settings: &NightLightSettings,
) {
    if *settings == state.night_light.settings {
        return;
    }
    let was_active = state.night_light.is_active();
    state.night_light.set_settings(settings, local_minute());
    sync_schedule_timer(state);
    start_fade(state);
    if state.night_light.is_active() != was_active {
        notify(state);
    }
}

/// The user's Helm toggle.
pub fn set_enabled<BackendData: Backend + 'static>(state: &mut State<BackendData>, enabled: bool) {
    // The minute timer may be up to a minute behind: decide on fresh ground.
    state.night_light.evaluate_schedule(local_minute());
    state.night_light.set_user_choice(enabled);
    start_fade(state);
    notify(state);
}

/// Tells the shell whether Night Light is on and whether any output can show
/// it. Sent on every change, on output changes and when the shell starts.
pub fn notify<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    let active = state.night_light.is_active();
    let supported = state.backend_data.color_gains_supported();
    let Some(flutter_engine) = state.flutter_engine.as_mut() else {
        return;
    };
    flutter_engine.platform_method_channel.invoke_method(
        "night_light_changed",
        Some(Box::new(json!({
            "active": active,
            "supported": supported,
        }))),
        None,
    );
}

/// Arms the minute timer that follows the schedule, or removes it when there
/// is no schedule. A monotonic timer stops during suspend; ticking every minute
/// keeps a resumed machine at most a minute late, and follows wall-clock and
/// DST changes without computing them.
fn sync_schedule_timer<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    let wanted = state.night_light.settings.schedule != NightLightSchedule::Off;
    match (wanted, state.night_light.schedule_token.is_some()) {
        (true, false) => {
            let token = state
                .loop_handle
                .insert_source(
                    Timer::from_duration(until_next_minute()),
                    |_, _, state: &mut State<BackendData>| {
                        let was_active = state.night_light.is_active();
                        state.night_light.evaluate_schedule(local_minute());
                        if state.night_light.is_active() != was_active {
                            start_fade(state);
                            notify(state);
                        }
                        TimeoutAction::ToDuration(until_next_minute())
                    },
                )
                .expect("Failed to insert the Night Light schedule timer");
            state.night_light.schedule_token = Some(token);
        }
        (false, true) => {
            if let Some(token) = state.night_light.schedule_token.take() {
                state.loop_handle.remove(token);
            }
        }
        _ => {}
    }
}

/// Fades toward the current target, arming the fade timer when needed.
fn start_fade<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    if !state.night_light.retarget(Instant::now()) || state.night_light.fade_token.is_some() {
        return;
    }
    let token = state
        .loop_handle
        .insert_source(
            Timer::immediate(),
            |_, _, state: &mut State<BackendData>| {
                let running = state.night_light.step_fade(Instant::now());
                let gains = state.night_light.gains();
                state.backend_data.set_color_gains(gains);
                if running {
                    TimeoutAction::ToDuration(FADE_STEP)
                } else {
                    state.night_light.fade_token = None;
                    TimeoutAction::Drop
                }
            },
        )
        .expect("Failed to insert the Night Light fade timer");
    state.night_light.fade_token = Some(token);
}

#[cfg(test)]
mod tests {
    use super::*;

    fn manual(from: &str, to: &str) -> NightLightSettings {
        NightLightSettings {
            schedule: NightLightSchedule::Manual,
            from: schedule::parse_time(from).unwrap(),
            to: schedule::parse_time(to).unwrap(),
            temperature: 2700,
        }
    }

    const NOON: u16 = 12 * 60;
    const NIGHT: u16 = 23 * 60;

    #[test]
    fn starts_at_its_temperature_without_fading() {
        let night = NightLight::new(&manual("20:00", "06:00"), NIGHT);
        assert!(night.is_active());
        assert_eq!(night.applied_kelvin, 2700.0);
        let day = NightLight::new(&manual("20:00", "06:00"), NOON);
        assert!(!day.is_active());
        assert_eq!(day.gains(), [1.0; 3]);
    }

    #[test]
    fn without_a_schedule_only_the_toggle_turns_it_on() {
        let mut light = NightLight::new(&NightLightSettings::default(), NIGHT);
        assert!(!light.is_active());
        light.set_user_choice(true);
        assert!(light.is_active());
        // No schedule transition ever clears it.
        light.evaluate_schedule(NOON);
        light.evaluate_schedule(NIGHT);
        assert!(light.is_active());
        light.set_user_choice(false);
        assert!(!light.is_active());
    }

    #[test]
    fn turning_it_off_at_night_holds_until_the_morning() {
        let mut light = NightLight::new(&manual("20:00", "06:00"), NIGHT);
        light.set_user_choice(false);
        assert!(!light.is_active());
        light.evaluate_schedule(2 * 60);
        assert!(!light.is_active(), "still the same night");
        // 06:00 ends the window and the override with it.
        light.evaluate_schedule(6 * 60);
        assert!(!light.is_active());
        assert_eq!(light.user_override, None);
        // The next evening turns it on again.
        light.evaluate_schedule(20 * 60);
        assert!(light.is_active());
    }

    #[test]
    fn turning_it_on_in_the_day_holds_through_the_next_night() {
        let mut light = NightLight::new(&manual("20:00", "06:00"), NOON);
        light.set_user_choice(true);
        assert!(light.is_active());
        light.evaluate_schedule(20 * 60);
        assert!(light.is_active());
        assert_eq!(light.user_override, None, "the schedule took over");
        light.evaluate_schedule(6 * 60);
        assert!(!light.is_active());
    }

    #[test]
    fn choosing_what_the_schedule_says_clears_the_override() {
        let mut light = NightLight::new(&manual("20:00", "06:00"), NIGHT);
        light.set_user_choice(false);
        light.set_user_choice(true);
        assert_eq!(light.user_override, None);
        assert!(light.is_active());
    }

    #[test]
    fn a_new_schedule_is_evaluated_at_once() {
        let mut light = NightLight::new(&NightLightSettings::default(), NIGHT);
        light.set_settings(&manual("20:00", "06:00"), NIGHT);
        assert!(light.is_active());
        light.set_settings(&NightLightSettings::default(), NIGHT);
        assert!(!light.is_active());
    }

    #[test]
    fn a_new_temperature_keeps_the_override() {
        let mut light = NightLight::new(&NightLightSettings::default(), NOON);
        light.set_user_choice(true);
        let warmer = NightLightSettings {
            temperature: 2000,
            ..NightLightSettings::default()
        };
        light.set_settings(&warmer, NOON);
        assert!(light.is_active());
        assert_eq!(light.target_kelvin(), 2000.0);
    }

    #[test]
    fn fades_from_where_it_is_to_the_target() {
        let mut light = NightLight::new(&NightLightSettings::default(), NOON);
        let start = Instant::now();
        light.set_user_choice(true);
        assert!(light.retarget(start));
        assert!(light.step_fade(start + FADE_DURATION / 2));
        let midway = light.applied_kelvin;
        assert!(midway < 6500.0 && midway > 2700.0, "{midway}");
        // Reversing mid-fade starts from the midway temperature.
        light.set_user_choice(false);
        assert!(light.retarget(start + FADE_DURATION / 2));
        assert_eq!(light.fade.unwrap().from, midway);
        assert!(!light.step_fade(start + FADE_DURATION * 2));
        assert_eq!(light.applied_kelvin, 6500.0);
        assert_eq!(light.gains(), [1.0; 3]);
    }

    #[test]
    fn retargeting_to_where_it_is_does_nothing() {
        let mut light = NightLight::new(&NightLightSettings::default(), NOON);
        assert!(!light.retarget(Instant::now()));
        assert!(light.fade.is_none());
    }

    #[test]
    fn settings_parse_leniently() {
        let settings: NightLightSettings = serde_json::from_value(json!({
            "schedule": "manual",
            "from": "21:30",
            "to": "07:15",
            "temperature": 3000,
        }))
        .unwrap();
        assert_eq!(settings, {
            let mut expected = manual("21:30", "07:15");
            expected.temperature = 3000;
            expected
        });

        let garbled: NightLightSettings = serde_json::from_value(json!({
            "schedule": "sometimes",
            "from": "25:00",
            "to": 7,
            "temperature": 100000,
        }))
        .unwrap();
        assert_eq!(garbled.schedule, NightLightSchedule::Off);
        assert_eq!(garbled.from, 20 * 60);
        assert_eq!(garbled.to, 6 * 60);
        assert_eq!(garbled.temperature, 6500);

        let missing: NightLightSettings = serde_json::from_value(json!({})).unwrap();
        assert_eq!(missing, NightLightSettings::default());
    }

    #[test]
    fn settings_round_trip_as_times_of_day() {
        let value = serde_json::to_value(manual("20:00", "06:00")).unwrap();
        assert_eq!(value["from"], "20:00");
        assert_eq!(value["to"], "06:00");
        assert_eq!(value["schedule"], "manual");
    }
}
