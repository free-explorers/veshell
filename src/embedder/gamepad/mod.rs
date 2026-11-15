//! Gamepads drive the shell's navigation.
//!
//! libinput ignores joysticks, so the compositor reads them itself: every
//! evdev node udev tags `ID_INPUT_JOYSTICK` is opened (through the seat
//! session on DRM), and its buttons, D-pad and sticks are normalised to one
//! logical [`GamepadButton`] set. The sticks become digital directions with a
//! hysteresis, so their noise never reaches the shell.
//!
//! The shell receives `gamepad_button` events and resolves them to its
//! navigation intents (see `docs/specifications/gamepad.md`). A game reads the
//! same device itself, so while a window is in gaming mode nothing is sent to
//! the shell: the only gesture the compositor keeps is a held Guide button,
//! which leaves gaming mode like `Ctrl+Esc`.

use std::collections::{HashMap, HashSet};
use std::os::fd::{AsRawFd, OwnedFd};
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::time::Duration;

use input_linux::{AbsoluteAxis, EvdevHandle};
use smithay::reexports::calloop::generic::Generic;
use smithay::reexports::calloop::timer::{TimeoutAction, Timer};
use smithay::reexports::calloop::{Interest, Mode, PostAction, RegistrationToken};
use tracing::{debug, info, warn};

use crate::backend::Backend;
use crate::state::State;

/// How long Guide must be held to leave gaming mode.
pub const GUIDE_HOLD_TO_LEAVE_GAME: Duration = Duration::from_millis(800);

/// Normalised stick deflection at which a direction is pressed.
const STICK_PRESS_THRESHOLD: f64 = 0.6;
/// Deflection under which a pressed direction is released again. Lower than
/// the press threshold, so a stick resting near it does not chatter.
const STICK_RELEASE_THRESHOLD: f64 = 0.4;

const EV_SYN: u16 = 0x00;
const EV_KEY: u16 = 0x01;
const EV_ABS: u16 = 0x03;
const SYN_DROPPED: u16 = 0x03;

/// A gamepad control, by position (the Linux gamepad API's naming): `south`
/// is A on an Xbox pad, Cross on a PlayStation pad and B on a Nintendo pad.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum GamepadButton {
    South,
    East,
    North,
    West,
    LeftShoulder,
    RightShoulder,
    LeftTrigger,
    RightTrigger,
    Select,
    Start,
    Guide,
    LeftThumb,
    RightThumb,
    DpadUp,
    DpadDown,
    DpadLeft,
    DpadRight,
    LeftStickUp,
    LeftStickDown,
    LeftStickLeft,
    LeftStickRight,
    RightStickUp,
    RightStickDown,
    RightStickLeft,
    RightStickRight,
}

impl GamepadButton {
    pub const ALL: [GamepadButton; 25] = [
        Self::South,
        Self::East,
        Self::North,
        Self::West,
        Self::LeftShoulder,
        Self::RightShoulder,
        Self::LeftTrigger,
        Self::RightTrigger,
        Self::Select,
        Self::Start,
        Self::Guide,
        Self::LeftThumb,
        Self::RightThumb,
        Self::DpadUp,
        Self::DpadDown,
        Self::DpadLeft,
        Self::DpadRight,
        Self::LeftStickUp,
        Self::LeftStickDown,
        Self::LeftStickLeft,
        Self::LeftStickRight,
        Self::RightStickUp,
        Self::RightStickDown,
        Self::RightStickLeft,
        Self::RightStickRight,
    ];

    /// The name the shell and the settings use.
    pub fn name(self) -> &'static str {
        match self {
            Self::South => "south",
            Self::East => "east",
            Self::North => "north",
            Self::West => "west",
            Self::LeftShoulder => "leftShoulder",
            Self::RightShoulder => "rightShoulder",
            Self::LeftTrigger => "leftTrigger",
            Self::RightTrigger => "rightTrigger",
            Self::Select => "select",
            Self::Start => "start",
            Self::Guide => "guide",
            Self::LeftThumb => "leftThumb",
            Self::RightThumb => "rightThumb",
            Self::DpadUp => "dpadUp",
            Self::DpadDown => "dpadDown",
            Self::DpadLeft => "dpadLeft",
            Self::DpadRight => "dpadRight",
            Self::LeftStickUp => "leftStickUp",
            Self::LeftStickDown => "leftStickDown",
            Self::LeftStickLeft => "leftStickLeft",
            Self::LeftStickRight => "leftStickRight",
            Self::RightStickUp => "rightStickUp",
            Self::RightStickDown => "rightStickDown",
            Self::RightStickLeft => "rightStickLeft",
            Self::RightStickRight => "rightStickRight",
        }
    }

    pub fn from_name(name: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|button| button.name() == name)
    }

    /// The button an `EV_KEY` code reports.
    ///
    /// `BTN_TRIGGER_HAPPY*` is deliberately left out: xpad reports a dance
    /// pad's D-pad there while hid-steam reports the Steam Deck's back
    /// paddles, so the code has no portable meaning.
    fn from_key_code(code: u16) -> Option<Self> {
        Some(match code {
            0x130 => Self::South,         // BTN_SOUTH
            0x131 => Self::East,          // BTN_EAST
            0x133 => Self::North,         // BTN_NORTH
            0x134 => Self::West,          // BTN_WEST
            0x136 => Self::LeftShoulder,  // BTN_TL
            0x137 => Self::RightShoulder, // BTN_TR
            0x138 => Self::LeftTrigger,   // BTN_TL2
            0x139 => Self::RightTrigger,  // BTN_TR2
            0x13a => Self::Select,        // BTN_SELECT
            0x13b => Self::Start,         // BTN_START
            0x13c => Self::Guide,         // BTN_MODE
            0x13d => Self::LeftThumb,     // BTN_THUMBL
            0x13e => Self::RightThumb,    // BTN_THUMBR
            0x220 => Self::DpadUp,        // BTN_DPAD_UP
            0x221 => Self::DpadDown,      // BTN_DPAD_DOWN
            0x222 => Self::DpadLeft,      // BTN_DPAD_LEFT
            0x223 => Self::DpadRight,     // BTN_DPAD_RIGHT
            _ => return None,
        })
    }
}

/// How an absolute axis turns into a pair of opposite directions.
#[derive(Clone, Copy, Debug)]
struct AxisDirections {
    negative: GamepadButton,
    positive: GamepadButton,
    /// Resting value and half the travel; a hat switch is `0`/`1`.
    center: f64,
    half_range: f64,
    /// A hat switch is digital already: any non-zero value is a press.
    is_hat: bool,
}

impl AxisDirections {
    /// The pressed state of `(negative, positive)` after `value`, given which
    /// of them were pressed before (the stick's hysteresis).
    fn resolve(&self, value: i32, was_negative: bool, was_positive: bool) -> (bool, bool) {
        if self.is_hat {
            return (value < 0, value > 0);
        }
        let deflection = ((value as f64 - self.center) / self.half_range).clamp(-1.0, 1.0);
        let negative = if was_negative {
            deflection < -STICK_RELEASE_THRESHOLD
        } else {
            deflection < -STICK_PRESS_THRESHOLD
        };
        let positive = if was_positive {
            deflection > STICK_RELEASE_THRESHOLD
        } else {
            deflection > STICK_PRESS_THRESHOLD
        };
        (negative, positive)
    }
}

/// The axes of a device that map to directions, from their reported ranges.
fn axis_directions(fd: &OwnedFd) -> HashMap<u16, AxisDirections> {
    use GamepadButton::*;
    let handle = EvdevHandle::new(fd.as_raw_fd());
    let candidates = [
        (AbsoluteAxis::X, LeftStickLeft, LeftStickRight, false),
        (AbsoluteAxis::Y, LeftStickUp, LeftStickDown, false),
        (AbsoluteAxis::RX, RightStickLeft, RightStickRight, false),
        (AbsoluteAxis::RY, RightStickUp, RightStickDown, false),
        (AbsoluteAxis::Hat0X, DpadLeft, DpadRight, true),
        (AbsoluteAxis::Hat0Y, DpadUp, DpadDown, true),
    ];
    let mut axes = HashMap::new();
    for (axis, negative, positive, is_hat) in candidates {
        // An axis the device lacks reads back with an empty range.
        let Ok(info) = handle.absolute_info(axis) else {
            continue;
        };
        if info.maximum <= info.minimum {
            continue;
        }
        // A hat switch reports -1..1. The Steam Deck reports its left
        // trackpad on the same axes with a full 16-bit range: a touch there
        // must not navigate.
        if is_hat && (info.minimum < -1 || info.maximum > 1) {
            continue;
        }
        axes.insert(
            axis as u16,
            AxisDirections {
                negative,
                positive,
                center: (info.minimum as f64 + info.maximum as f64) / 2.0,
                half_range: (info.maximum as f64 - info.minimum as f64) / 2.0,
                is_hat,
            },
        );
    }
    axes
}

struct GamepadDevice {
    /// Shared with the event-loop source; reclaimed on removal to close it
    /// through the backend (the seat session tracks what it opened).
    fd: Rc<OwnedFd>,
    token: RegistrationToken,
    axes: HashMap<u16, AxisDirections>,
    pressed: HashSet<GamepadButton>,
}

/// Which device holds a logical button: the probe injects as its own.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum GamepadSource {
    Device(PathBuf),
    Probe,
}

#[derive(Default)]
pub struct GamepadState {
    devices: HashMap<PathBuf, GamepadDevice>,
    /// Every source holding each logical button. Several pads (or a pad and
    /// the virtual one Steam mirrors it to) act as one: a button is pressed
    /// while any of them holds it.
    held: HashMap<GamepadButton, HashSet<GamepadSource>>,
    /// Buttons whose press reached the shell and whose release it still
    /// expects. A press swallowed by gaming mode never gets a release, and
    /// entering gaming mode releases these.
    sent_to_shell: HashSet<GamepadButton>,
    guide_hold: Option<RegistrationToken>,
    udev_monitor: Option<RegistrationToken>,
}

/// Starts watching for gamepads: opens those present and follows hotplug.
///
/// The isolated `veshell-probe` instance never opens the developer's real
/// pads; it gets gamepad input from `inject` instead.
pub fn init<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    if std::env::var_os("VESHELL_PROBE_ISOLATED").is_some_and(|value| value == "1") {
        info!("gamepad: isolated probe instance, real devices are not opened");
        return;
    }
    let socket = match udev::MonitorBuilder::new()
        .and_then(|builder| builder.match_subsystem("input"))
        .and_then(|builder| builder.listen())
    {
        Ok(socket) => socket,
        Err(err) => {
            warn!(
                ?err,
                "gamepad: cannot monitor input devices, hotplug disabled"
            );
            scan(state);
            return;
        }
    };
    let token = state.loop_handle.insert_source(
        Generic::new(socket, Interest::READ, Mode::Level),
        |_, socket, state: &mut State<BackendData>| {
            for event in socket.iter() {
                let device = event.device();
                let Some(path) = gamepad_node(&device) else {
                    continue;
                };
                match event.event_type() {
                    udev::EventType::Add => open(state, path),
                    udev::EventType::Remove => close(state, &path),
                    _ => {}
                }
            }
            Ok(PostAction::Continue)
        },
    );
    match token {
        Ok(token) => state.gamepads.udev_monitor = Some(token),
        Err(err) => warn!(?err, "gamepad: cannot watch input hotplug"),
    }
    scan(state);
}

/// The evdev node of a udev device, when it is a gamepad of this seat.
fn gamepad_node(device: &udev::Device) -> Option<PathBuf> {
    if device
        .property_value("ID_INPUT_JOYSTICK")
        .is_none_or(|value| value != "1")
    {
        return None;
    }
    let path = device.devnode()?;
    // A joystick also has a legacy `/dev/input/jsN` node: read the evdev one.
    if !path.file_name()?.to_str()?.starts_with("event") {
        return None;
    }
    Some(path.to_path_buf())
}

/// Opens every gamepad already present.
fn scan<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    let devices = udev::Enumerator::new().and_then(|mut enumerator| {
        enumerator.match_subsystem("input")?;
        enumerator.match_property("ID_INPUT_JOYSTICK", "1")?;
        Ok(enumerator
            .scan_devices()?
            .filter_map(|device| gamepad_node(&device))
            .collect::<Vec<_>>())
    });
    match devices {
        Ok(paths) => {
            for path in paths {
                open(state, path);
            }
        }
        Err(err) => warn!(?err, "gamepad: cannot enumerate input devices"),
    }
}

fn open<BackendData: Backend + 'static>(state: &mut State<BackendData>, path: PathBuf) {
    if state.gamepads.devices.contains_key(&path) || !state.backend_data.input_session_active() {
        return;
    }
    let fd = match state.backend_data.open_input_device(&path) {
        Ok(fd) => Rc::new(fd),
        Err(err) => {
            warn!(?err, path = %path.display(), "gamepad: cannot open");
            return;
        }
    };
    let axes = axis_directions(&fd);
    let source_path = path.clone();
    let token = state.loop_handle.insert_source(
        Generic::new(fd.clone(), Interest::READ, Mode::Level),
        move |_, _, state: &mut State<BackendData>| {
            if read(state, &source_path) {
                Ok(PostAction::Continue)
            } else {
                // Unplugged, or revoked by a session switch.
                close(state, &source_path);
                Ok(PostAction::Remove)
            }
        },
    );
    let token = match token {
        Ok(token) => token,
        Err(err) => {
            warn!(?err, path = %path.display(), "gamepad: cannot watch");
            return;
        }
    };
    info!(path = %path.display(), "gamepad: opened");
    state.gamepads.devices.insert(
        path,
        GamepadDevice {
            fd,
            token,
            axes,
            pressed: HashSet::new(),
        },
    );
}

fn close<BackendData: Backend + 'static>(state: &mut State<BackendData>, path: &Path) {
    let Some(device) = state.gamepads.devices.remove(path) else {
        return;
    };
    state.loop_handle.remove(device.token);
    let source = GamepadSource::Device(path.to_path_buf());
    for button in device.pressed {
        set_held(state, source.clone(), button, false);
    }
    // The removed source dropped its clone; the last one closes the fd.
    if let Ok(fd) = Rc::try_unwrap(device.fd) {
        state.backend_data.close_input_device(fd);
    }
    info!(path = %path.display(), "gamepad: closed");
}

/// Closes every gamepad: the seat session is being paused and revokes them.
pub fn suspend<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    let paths: Vec<PathBuf> = state.gamepads.devices.keys().cloned().collect();
    for path in paths {
        close(state, &path);
    }
}

/// Reopens the gamepads after the seat session is active again.
pub fn resume<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    if std::env::var_os("VESHELL_PROBE_ISOLATED").is_some_and(|value| value == "1") {
        return;
    }
    scan(state);
}

/// Drains a device. Returns `false` once it is gone.
fn read<BackendData: Backend + 'static>(state: &mut State<BackendData>, path: &Path) -> bool {
    // SAFETY: `input_event` is plain old data.
    let mut events: [libc::input_event; 64] = unsafe { std::mem::zeroed() };
    loop {
        let Some(device) = state.gamepads.devices.get(path) else {
            return false;
        };
        let fd = device.fd.as_raw_fd();
        // SAFETY: the buffer is valid for its whole size.
        let read = unsafe {
            libc::read(
                fd,
                events.as_mut_ptr().cast(),
                std::mem::size_of_val(&events),
            )
        };
        if read < 0 {
            let err = std::io::Error::last_os_error();
            return match err.kind() {
                std::io::ErrorKind::WouldBlock => true,
                std::io::ErrorKind::Interrupted => continue,
                _ => {
                    debug!(?err, path = %path.display(), "gamepad: read failed");
                    false
                }
            };
        }
        if read == 0 {
            return false;
        }
        let count = read as usize / std::mem::size_of::<libc::input_event>();
        for event in &events[..count] {
            handle_event(state, path, event);
        }
    }
}

fn handle_event<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    path: &Path,
    event: &libc::input_event,
) {
    let source = GamepadSource::Device(path.to_path_buf());
    match event.type_ {
        EV_KEY => {
            // 2 is the kernel's autorepeat: the shell repeats itself.
            if event.value == 2 {
                return;
            }
            if let Some(button) = GamepadButton::from_key_code(event.code) {
                device_button(state, path, source, button, event.value != 0);
            }
        }
        EV_ABS => {
            let Some(device) = state.gamepads.devices.get(path) else {
                return;
            };
            let Some(axis) = device.axes.get(&event.code).copied() else {
                return;
            };
            let (negative, positive) = axis.resolve(
                event.value,
                device.pressed.contains(&axis.negative),
                device.pressed.contains(&axis.positive),
            );
            device_button(state, path, source.clone(), axis.negative, negative);
            device_button(state, path, source, axis.positive, positive);
        }
        EV_SYN if event.code == SYN_DROPPED => {
            // The kernel dropped events: what is held is unknown until the
            // device reports again, so let go of everything rather than leave
            // a direction held (and repeating) forever.
            let pressed: Vec<GamepadButton> = state
                .gamepads
                .devices
                .get(path)
                .map(|device| device.pressed.iter().copied().collect())
                .unwrap_or_default();
            for button in pressed {
                device_button(state, path, source.clone(), button, false);
            }
        }
        _ => {}
    }
}

fn device_button<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    path: &Path,
    source: GamepadSource,
    button: GamepadButton,
    pressed: bool,
) {
    let Some(device) = state.gamepads.devices.get_mut(path) else {
        return;
    };
    let changed = if pressed {
        device.pressed.insert(button)
    } else {
        device.pressed.remove(&button)
    };
    if changed {
        set_held(state, source, button, pressed);
    }
}

/// Records that `source` pressed or released `button`, and handles the
/// logical button when that changes whether any source holds it.
pub fn set_held<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    source: GamepadSource,
    button: GamepadButton,
    pressed: bool,
) {
    let holders = state.gamepads.held.entry(button).or_default();
    let was_held = !holders.is_empty();
    if pressed {
        holders.insert(source);
    } else {
        holders.remove(&source);
    }
    let is_held = !holders.is_empty();
    if was_held != is_held {
        on_button(state, button, is_held);
    }
}

fn on_button<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    button: GamepadButton,
    pressed: bool,
) {
    // A game played with a pad is activity too: the screen must not dim
    // under it. Only digital transitions count, never stick noise.
    crate::idle::on_activity(state);

    if state.meta_window_state.meta_window_in_gaming_mode.is_some() {
        // The game reads the pad itself; the shell must stay out of the way.
        if button == GamepadButton::Guide {
            if pressed {
                arm_guide_hold(state);
            } else {
                cancel_guide_hold(state);
            }
        }
        return;
    }
    if button == GamepadButton::Guide && !pressed {
        cancel_guide_hold(state);
    }

    if pressed {
        state.gamepads.sent_to_shell.insert(button);
    } else if !state.gamepads.sent_to_shell.remove(&button) {
        // Its press was swallowed by gaming mode.
        return;
    }
    send_to_shell(state, button, pressed);
}

fn send_to_shell<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    button: GamepadButton,
    pressed: bool,
) {
    let Some(engine) = state.flutter_engine.as_mut() else {
        return;
    };
    engine.platform_method_channel.invoke_method(
        "gamepad_button",
        Some(Box::new(serde_json::json!({
            "button": button.name(),
            "pressed": pressed,
        }))),
        None,
    );
}

fn arm_guide_hold<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    cancel_guide_hold(state);
    let token = state.loop_handle.insert_source(
        Timer::from_duration(GUIDE_HOLD_TO_LEAVE_GAME),
        |_, _, state: &mut State<BackendData>| {
            state.gamepads.guide_hold = None;
            info!("gamepad: Guide held, leaving gaming mode");
            crate::keyboard::leave_gaming_mode(state);
            TimeoutAction::Drop
        },
    );
    match token {
        Ok(token) => state.gamepads.guide_hold = Some(token),
        Err(err) => warn!(?err, "gamepad: cannot time the Guide hold"),
    }
}

fn cancel_guide_hold<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    if let Some(token) = state.gamepads.guide_hold.take() {
        state.loop_handle.remove(token);
    }
}

/// Hands the pad to a game entering gaming mode: the shell gets a release for
/// every button it still believes is held, so none keeps repeating behind the
/// game.
pub fn release_shell_buttons<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    for button in std::mem::take(&mut state.gamepads.sent_to_shell) {
        send_to_shell(state, button, false);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn stick() -> AxisDirections {
        AxisDirections {
            negative: GamepadButton::LeftStickLeft,
            positive: GamepadButton::LeftStickRight,
            center: 0.0,
            half_range: 32767.0,
            is_hat: false,
        }
    }

    #[test]
    fn a_resting_stick_presses_nothing() {
        assert_eq!(stick().resolve(1200, false, false), (false, false));
        assert_eq!(stick().resolve(-1200, false, false), (false, false));
    }

    #[test]
    fn a_deflected_stick_presses_its_direction() {
        assert_eq!(stick().resolve(30000, false, false), (false, true));
        assert_eq!(stick().resolve(-30000, false, false), (true, false));
    }

    #[test]
    fn a_stick_between_thresholds_keeps_its_state() {
        // 0.5: above the release threshold, below the press one.
        let half = 16384;
        assert_eq!(stick().resolve(half, false, false), (false, false));
        assert_eq!(stick().resolve(half, false, true), (false, true));
    }

    #[test]
    fn an_offset_range_is_centered() {
        // hid-playstation reports 0..255.
        let axis = AxisDirections {
            center: 127.5,
            half_range: 127.5,
            ..stick()
        };
        assert_eq!(axis.resolve(128, false, false), (false, false));
        assert_eq!(axis.resolve(255, false, false), (false, true));
        assert_eq!(axis.resolve(0, false, false), (true, false));
    }

    #[test]
    fn a_hat_is_digital() {
        let hat = AxisDirections {
            negative: GamepadButton::DpadUp,
            positive: GamepadButton::DpadDown,
            center: 0.0,
            half_range: 1.0,
            is_hat: true,
        };
        assert_eq!(hat.resolve(-1, false, false), (true, false));
        assert_eq!(hat.resolve(0, true, false), (false, false));
        assert_eq!(hat.resolve(1, false, false), (false, true));
    }

    #[test]
    fn button_names_round_trip() {
        for button in GamepadButton::ALL {
            assert_eq!(GamepadButton::from_name(button.name()), Some(button));
        }
    }
}
