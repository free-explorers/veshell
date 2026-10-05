//! Display backlight brightness.
//!
//! The compositor owns the physical backlight for two reasons: the screensaver
//! can fade the panel instead of only painting a black overlay, and the
//! brightness keys have a single authority to talk to. Values go through
//! `logind` when the system bus is available (permission-safe) and fall back to
//! the kernel's `/sys/class/backlight` interface; see [`backlight`].
//!
//! Brightness is in-memory only: the user's level is measured from the hardware
//! at startup and the screensaver restores it on wake.

use std::sync::mpsc::{self, Sender};
use std::thread;

use backlight::BacklightDevice;

mod backlight;

/// Fraction of the user's brightness the panel fades to while the screensaver
/// is dimmed. The blank stage turns the backlight fully off instead.
const IDLE_DIM_FRACTION: f32 = 0.1;

/// The user level never reaches zero: a brightness of `0` turns the panel off,
/// which is reserved for the screensaver. One percent keeps the lowest setting
/// readable while still letting the panel go almost fully dark.
const MIN_USER_FRACTION: f32 = 0.01;

/// One brightness write for one device, in raw kernel units.
pub(crate) struct Update {
    pub(crate) path: std::path::PathBuf,
    pub(crate) name: String,
    pub(crate) value: u32,
}

/// The brightness the panel should show, in the render loop's terms.
pub struct Brightness {
    devices: Vec<BacklightDevice>,
    /// The level the user chose, in `[MIN_USER_FRACTION, 1]`.
    user_fraction: f32,
    /// `0` = awake, `1` = fully dimmed. The fade interpolates between them.
    idle_progress: f32,
    /// The blank stage turns the backlight off outright.
    blank: bool,
    sender: Option<Sender<Vec<Update>>>,
}

impl Brightness {
    /// Discover the backlight and start the writer thread. `enabled` is the
    /// backend's [`crate::backend::Backend::CONTROLS_BACKLIGHT`]: a nested
    /// backend must never dim its host's panel.
    pub fn new(enabled: bool) -> Self {
        if !enabled {
            return Self::disabled();
        }
        let devices = backlight::discover();
        if devices.is_empty() {
            return Self::disabled();
        }
        let user_fraction = backlight::read_fraction(&devices).unwrap_or(1.0);
        let (sender, receiver) = mpsc::channel::<Vec<Update>>();
        thread::Builder::new()
            .name("brightness".to_owned())
            .spawn(move || backlight::run(receiver))
            .expect("Failed to start the brightness writer thread");
        Self {
            devices,
            user_fraction: user_fraction.clamp(MIN_USER_FRACTION, 1.0),
            idle_progress: 0.0,
            blank: false,
            sender: Some(sender),
        }
    }

    fn disabled() -> Self {
        Self {
            devices: Vec::new(),
            user_fraction: 1.0,
            idle_progress: 0.0,
            blank: false,
            sender: None,
        }
    }

    /// Whether a controllable backlight exists. When false the screensaver must
    /// keep using the black overlay.
    pub fn is_available(&self) -> bool {
        self.sender.is_some()
    }

    /// Move the user level by `delta`, clamped so the panel never turns off.
    pub fn adjust(&mut self, delta: f32) {
        self.user_fraction = (self.user_fraction + delta).clamp(MIN_USER_FRACTION, 1.0);
        self.apply();
    }

    /// Drive the screensaver fade. `progress` runs from `0` (awake) to `1`
    /// (fully dimmed); when `blank` is set the backlight turns off outright,
    /// which wins over the fade.
    pub fn set_idle(&mut self, progress: f32, blank: bool) {
        self.idle_progress = progress.clamp(0.0, 1.0);
        self.blank = blank;
        self.apply();
    }

    /// Waking shortcut: full user level, no blank.
    pub fn wake(&mut self) {
        self.set_idle(0.0, false);
    }

    fn apply(&self) {
        let Some(sender) = &self.sender else {
            return;
        };
        let fraction = target_fraction(self.user_fraction, self.idle_progress, self.blank);
        let updates = self
            .devices
            .iter()
            .map(|device| {
                let raw = (fraction * device.max_brightness as f32).round() as u32;
                // `0` is only ever written while blanking; the awake level keeps
                // at least one step so the panel never reads as off.
                let value = if self.blank { raw } else { raw.max(1) };
                Update {
                    path: device.path.clone(),
                    name: device.name.clone(),
                    value,
                }
            })
            .collect();
        // Unbounded: the worker coalesces bursts, so the compositor never
        // blocks on a slow logind round-trip.
        let _ = sender.send(updates);
    }
}

/// The panel fraction for the current state. Dimming fades toward
/// `IDLE_DIM_FRACTION` but never brighter than the user's own level, so a panel
/// already below the floor stays put. Blanking overrides everything.
fn target_fraction(user_fraction: f32, idle_progress: f32, blank: bool) -> f32 {
    if blank {
        return 0.0;
    }
    let floor = user_fraction.min(IDLE_DIM_FRACTION);
    user_fraction + (floor - user_fraction) * idle_progress
}

#[cfg(test)]
mod tests {
    use super::{target_fraction, IDLE_DIM_FRACTION};

    #[test]
    fn awake_uses_the_user_level_verbatim() {
        assert_eq!(target_fraction(0.5, 0.0, false), 0.5);
        assert_eq!(target_fraction(1.0, 0.0, false), 1.0);
    }

    #[test]
    fn full_dim_reaches_the_floor() {
        assert!((target_fraction(1.0, 1.0, false) - IDLE_DIM_FRACTION).abs() < 1e-6);
        assert!((target_fraction(0.8, 1.0, false) - 0.1).abs() < 1e-6);
    }

    #[test]
    fn dimming_never_brightens_a_panel_below_the_floor() {
        assert_eq!(target_fraction(0.05, 1.0, false), 0.05);
        assert_eq!(target_fraction(0.05, 0.5, false), 0.05);
    }

    #[test]
    fn blank_turns_the_backlight_off_regardless_of_progress() {
        assert_eq!(target_fraction(1.0, 0.0, true), 0.0);
        assert_eq!(target_fraction(1.0, 1.0, true), 0.0);
    }
}
