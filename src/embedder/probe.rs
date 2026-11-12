//! `veshell-probe`'s control socket, in debug builds only (see
//! `docs/specifications/veshell_probe.md`).
//!
//! The shell side of the probe sees what Flutter draws; this side sees what
//! the compositor shows and feeds it input the way a device does:
//!
//! - `outputs`: the outputs, their logical geometry and scale;
//! - `capture_output`: the composited output, application windows included,
//!   written as a PNG to the path the request gives;
//! - `inject`: pointer motion, buttons and wheel through the compositor's
//!   own input handlers, and keys through the keyboard handler, so focus,
//!   Super chords, Flutter and Wayland clients all see them as real input.
//!
//! Requests and replies are JSON, one per line, on the Unix socket
//! `$XDG_RUNTIME_DIR/veshell-probe-<wayland socket>.sock` (private to the
//! user), which the embedder exports as `VESHELL_PROBE_SOCKET`. A thread
//! serves the socket and hands each request to the event loop.

use std::io::{BufRead, BufReader, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::PathBuf;
use std::sync::mpsc;
use std::time::Duration;

use serde_json::{json, Value};
use smithay::backend::input::{
    AbsolutePositionEvent, Axis, AxisRelativeDirection, AxisSource, ButtonState, Device,
    DeviceCapability, Event, InputBackend, KeyState, PointerAxisEvent, PointerButtonEvent,
    PointerMotionAbsoluteEvent, UnusedEvent,
};
use smithay::input::keyboard::Keycode;
use smithay::reexports::calloop::{channel, LoopHandle};
use smithay::utils::{Logical, Physical, Point, Rectangle, Size};
use tracing::{info, warn};

use crate::backend::Backend;
use crate::state::State;

/// The environment variable the socket's path is published in.
pub const SOCKET_VARIABLE: &str = "VESHELL_PROBE_SOCKET";

/// How long a request may wait for the event loop. Generous: a capture
/// renders the output and encodes a PNG on the loop, which takes seconds on a
/// large output with software GL.
const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);

struct ProbeRequest {
    request: Value,
    reply: mpsc::Sender<Value>,
}

/// Where the socket of the compositor on Wayland socket [socket_name] lives.
fn socket_path(socket_name: &str) -> Option<PathBuf> {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(|directory| PathBuf::from(directory).join(format!("veshell-probe-{socket_name}.sock")))
}

/// Serves the control socket of the compositor on Wayland socket
/// [socket_name].
pub fn install<BackendData: Backend + 'static>(
    loop_handle: &LoopHandle<'static, State<BackendData>>,
    socket_name: &str,
) {
    let Some(path) = socket_path(socket_name) else {
        warn!("veshell-probe: no XDG_RUNTIME_DIR, no control socket");
        return;
    };
    // A socket left by a previous run on the same Wayland socket name.
    let _ = std::fs::remove_file(&path);
    let listener = match UnixListener::bind(&path) {
        Ok(listener) => listener,
        Err(error) => {
            warn!(
                "veshell-probe: cannot listen on {}: {error}",
                path.display()
            );
            return;
        }
    };
    // XDG_RUNTIME_DIR is private to the user (0700) already: this only
    // narrows the socket itself, and a failure is reported, not fatal.
    if let Err(error) = std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600)) {
        warn!(
            "veshell-probe: cannot restrict {} to its owner: {error}",
            path.display()
        );
    }

    let (sender, receiver) = channel::channel::<ProbeRequest>();
    if let Err(error) = loop_handle.insert_source(receiver, |event, _, state| {
        if let channel::Event::Msg(request) = event {
            let reply = handle(state, &request.request);
            let _ = request.reply.send(reply);
        }
    }) {
        warn!("veshell-probe: cannot serve the control socket: {error}");
        return;
    }
    std::env::set_var(SOCKET_VARIABLE, &path);
    info!("veshell-probe: control socket {}", path.display());

    std::thread::spawn(move || {
        for stream in listener.incoming().flatten() {
            let sender = sender.clone();
            std::thread::spawn(move || serve(stream, sender));
        }
    });
}

fn serve(stream: UnixStream, sender: channel::Sender<ProbeRequest>) {
    let Ok(reader) = stream.try_clone() else {
        return;
    };
    let mut writer = stream;
    for line in BufReader::new(reader).lines() {
        let Ok(line) = line else {
            return;
        };
        if line.trim().is_empty() {
            continue;
        }
        let reply = match serde_json::from_str::<Value>(&line) {
            Ok(request) => {
                let (reply_sender, reply_receiver) = mpsc::channel();
                if sender
                    .send(ProbeRequest {
                        request,
                        reply: reply_sender,
                    })
                    .is_err()
                {
                    return;
                }
                reply_receiver
                    .recv_timeout(REQUEST_TIMEOUT)
                    .unwrap_or_else(|_| json!({ "error": "the compositor did not answer" }))
            }
            Err(error) => json!({ "error": format!("not JSON: {error}") }),
        };
        if writeln!(writer, "{reply}").is_err() {
            return;
        }
    }
}

fn handle<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    request: &Value,
) -> Value {
    // Input and captures go through the Flutter engine: until it runs (at
    // startup), refuse them instead of panicking.
    let needs_engine = matches!(request["op"].as_str(), Some("capture_output" | "inject"));
    if needs_engine && state.flutter_engine.is_none() {
        return json!({ "error": "the shell is not running yet: retry shortly" });
    }
    let result = match request["op"].as_str() {
        Some("outputs") => Ok(outputs(state)),
        Some("capture_output") => capture_output(state, request),
        Some("inject") => inject(state, request),
        other => Err(format!(
            "unknown op {other:?}: outputs, capture_output or inject"
        )),
    };
    result.unwrap_or_else(|error| json!({ "error": error }))
}

fn outputs<BackendData: Backend + 'static>(state: &State<BackendData>) -> Value {
    let outputs = state
        .space
        .outputs()
        .map(|output| {
            let geometry = state.space.output_geometry(output);
            let mode = output.current_mode();
            json!({
                "name": output.name(),
                "geometry": geometry.map(rectangle_json),
                "scale": output.current_scale().fractional_scale(),
                "pixelSize": mode.map(|mode| [mode.size.w, mode.size.h]),
            })
        })
        .collect::<Vec<_>>();
    json!({ "outputs": outputs })
}

fn rectangle_json(rectangle: Rectangle<i32, Logical>) -> Value {
    json!({
        "left": rectangle.loc.x,
        "top": rectangle.loc.y,
        "width": rectangle.size.w,
        "height": rectangle.size.h,
    })
}

fn capture_output<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    request: &Value,
) -> Result<Value, String> {
    let path = request["path"]
        .as_str()
        .ok_or("capture_output needs the path to write the PNG to")?;
    let output = match request["output"].as_str() {
        Some(name) => state
            .space
            .outputs()
            .find(|output| output.name() == name)
            .cloned()
            .ok_or_else(|| format!("no output {name}"))?,
        None => state.space.outputs().next().cloned().ok_or("no output")?,
    };
    let (size, pixels): (Size<i32, Physical>, Vec<u8>) =
        crate::capture::capture_full_output(state, &output)?;
    crate::capture::encode_and_write_png(size, &pixels, std::path::Path::new(path))?;
    Ok(json!({
        "output": output.name(),
        "path": path,
        "pixelWidth": size.w,
        "pixelHeight": size.h,
    }))
}

fn inject<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    request: &Value,
) -> Result<Value, String> {
    let events = request["events"]
        .as_array()
        .ok_or("inject needs an events array")?;
    let mut injected = 0;
    for event in events {
        inject_one(state, event)?;
        injected += 1;
    }
    Ok(json!({ "injected": injected }))
}

fn now_micros<BackendData: Backend + 'static>(state: &State<BackendData>) -> u64 {
    Duration::from(state.clock.now()).as_micros() as u64
}

fn inject_one<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    event: &Value,
) -> Result<(), String> {
    let time = now_micros(state);
    match event["type"].as_str() {
        Some("motion") => {
            let x = event["x"].as_f64().ok_or("motion needs x")?;
            let y = event["y"].as_f64().ok_or("motion needs y")?;
            // The handler maps the event onto the outputs' bounding box: give
            // it the offset from that box's corner.
            let bounds = state
                .space
                .outputs()
                .filter_map(|output| state.space.output_geometry(output))
                .reduce(|bounds, geometry| bounds.merge(geometry))
                .ok_or("no output")?;
            let offset = Point::from((x - bounds.loc.x as f64, y - bounds.loc.y as f64));
            state.on_pointer_motion_absolute::<ProbeInput>(ProbeMotion { offset, time }, 0, 0);
        }
        Some("button") => {
            let code = button_code(&event["button"])?;
            let pressed = pressed(&event["state"])?;
            let view_id = state.view_id_under_pointer();
            state.on_pointer_button::<ProbeInput>(
                ProbeButton {
                    code,
                    state: if pressed {
                        ButtonState::Pressed
                    } else {
                        ButtonState::Released
                    },
                    time,
                },
                0,
                view_id,
            );
        }
        Some("axis") => {
            let view_id = state.view_id_under_pointer();
            state.on_pointer_axis::<ProbeInput>(
                ProbeAxis {
                    horizontal: event["dx"].as_f64().unwrap_or(0.0),
                    vertical: event["dy"].as_f64().unwrap_or(0.0),
                    time,
                },
                0,
                view_id,
            );
        }
        Some("key") => {
            let code = key_code(&event["key"])?;
            let pressed = pressed(&event["state"])?;
            crate::keyboard::handle_keyboard_event(
                state,
                Keycode::new(code + 8),
                if pressed {
                    KeyState::Pressed
                } else {
                    KeyState::Released
                },
                (time / 1000) as u32,
                false,
            );
        }
        other => {
            return Err(format!(
                "unknown event type {other:?}: motion, button, axis or key"
            ))
        }
    }
    state.request_render();
    Ok(())
}

fn pressed(value: &Value) -> Result<bool, String> {
    match value.as_str() {
        Some("pressed") => Ok(true),
        Some("released") => Ok(false),
        other => Err(format!("state must be pressed or released, not {other:?}")),
    }
}

fn button_code(value: &Value) -> Result<u32, String> {
    if let Some(code) = value.as_u64() {
        return Ok(code as u32);
    }
    match value.as_str().unwrap_or("left") {
        "left" => Ok(0x110),
        "right" => Ok(0x111),
        "middle" => Ok(0x112),
        other => Err(format!(
            "unknown button {other:?}: left, right, middle or a code"
        )),
    }
}

/// A Linux key code (`input-event-codes.h`), from a code or a key name.
fn key_code(value: &Value) -> Result<u32, String> {
    if let Some(code) = value.as_u64() {
        return Ok(code as u32);
    }
    let name = value
        .as_str()
        .ok_or("key needs a key name or code")?
        .to_lowercase()
        .replace(' ', "");
    linux_key_code(&name).ok_or_else(|| format!("unknown key {name:?}"))
}

fn linux_key_code(name: &str) -> Option<u32> {
    use input_linux::sys as keys;
    let code = match name {
        "escape" | "esc" => keys::KEY_ESC,
        "enter" | "return" => keys::KEY_ENTER,
        "tab" => keys::KEY_TAB,
        "backspace" => keys::KEY_BACKSPACE,
        "delete" => keys::KEY_DELETE,
        "space" => keys::KEY_SPACE,
        "up" | "arrowup" => keys::KEY_UP,
        "down" | "arrowdown" => keys::KEY_DOWN,
        "left" | "arrowleft" => keys::KEY_LEFT,
        "right" | "arrowright" => keys::KEY_RIGHT,
        "home" => keys::KEY_HOME,
        "end" => keys::KEY_END,
        "pageup" => keys::KEY_PAGEUP,
        "pagedown" => keys::KEY_PAGEDOWN,
        "super" | "meta" | "logo" => keys::KEY_LEFTMETA,
        "control" | "ctrl" => keys::KEY_LEFTCTRL,
        "shift" => keys::KEY_LEFTSHIFT,
        "alt" => keys::KEY_LEFTALT,
        "altright" | "rightalt" | "altgr" => keys::KEY_RIGHTALT,
        "apostrophe" | "quote" => keys::KEY_APOSTROPHE,
        _ => return letter_or_digit_code(name),
    };
    Some(code as u32)
}

fn letter_or_digit_code(name: &str) -> Option<u32> {
    use input_linux::sys as keys;
    let mut characters = name.chars();
    let (Some(character), None) = (characters.next(), characters.next()) else {
        return None;
    };
    let code = match character {
        'a' => keys::KEY_A,
        'b' => keys::KEY_B,
        'c' => keys::KEY_C,
        'd' => keys::KEY_D,
        'e' => keys::KEY_E,
        'f' => keys::KEY_F,
        'g' => keys::KEY_G,
        'h' => keys::KEY_H,
        'i' => keys::KEY_I,
        'j' => keys::KEY_J,
        'k' => keys::KEY_K,
        'l' => keys::KEY_L,
        'm' => keys::KEY_M,
        'n' => keys::KEY_N,
        'o' => keys::KEY_O,
        'p' => keys::KEY_P,
        'q' => keys::KEY_Q,
        'r' => keys::KEY_R,
        's' => keys::KEY_S,
        't' => keys::KEY_T,
        'u' => keys::KEY_U,
        'v' => keys::KEY_V,
        'w' => keys::KEY_W,
        'x' => keys::KEY_X,
        'y' => keys::KEY_Y,
        'z' => keys::KEY_Z,
        '0' => keys::KEY_0,
        '1' => keys::KEY_1,
        '2' => keys::KEY_2,
        '3' => keys::KEY_3,
        '4' => keys::KEY_4,
        '5' => keys::KEY_5,
        '6' => keys::KEY_6,
        '7' => keys::KEY_7,
        '8' => keys::KEY_8,
        '9' => keys::KEY_9,
        _ => return None,
    };
    Some(code as u32)
}

/// The input the probe injects, as a Smithay input backend: its events go
/// through the very handlers a device's do.
#[derive(Debug)]
pub struct ProbeInput;

/// The probe's (virtual) input device.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ProbeDevice;

impl Device for ProbeDevice {
    fn id(&self) -> String {
        "veshell-probe".into()
    }

    fn name(&self) -> String {
        "veshell-probe".into()
    }

    fn has_capability(&self, capability: DeviceCapability) -> bool {
        matches!(
            capability,
            DeviceCapability::Pointer | DeviceCapability::Keyboard
        )
    }

    fn usb_id(&self) -> Option<(u32, u32)> {
        None
    }

    fn syspath(&self) -> Option<PathBuf> {
        None
    }
}

impl InputBackend for ProbeInput {
    type Device = ProbeDevice;
    type KeyboardKeyEvent = UnusedEvent;
    type PointerAxisEvent = ProbeAxis;
    type PointerButtonEvent = ProbeButton;
    type PointerMotionEvent = UnusedEvent;
    type PointerMotionAbsoluteEvent = ProbeMotion;
    type GestureSwipeBeginEvent = UnusedEvent;
    type GestureSwipeUpdateEvent = UnusedEvent;
    type GestureSwipeEndEvent = UnusedEvent;
    type GesturePinchBeginEvent = UnusedEvent;
    type GesturePinchUpdateEvent = UnusedEvent;
    type GesturePinchEndEvent = UnusedEvent;
    type GestureHoldBeginEvent = UnusedEvent;
    type GestureHoldEndEvent = UnusedEvent;
    type TouchDownEvent = UnusedEvent;
    type TouchUpEvent = UnusedEvent;
    type TouchMotionEvent = UnusedEvent;
    type TouchCancelEvent = UnusedEvent;
    type TouchFrameEvent = UnusedEvent;
    type TabletToolAxisEvent = UnusedEvent;
    type TabletToolProximityEvent = UnusedEvent;
    type TabletToolTipEvent = UnusedEvent;
    type TabletToolButtonEvent = UnusedEvent;
    type SwitchToggleEvent = UnusedEvent;
    type SpecialEvent = UnusedEvent;
}

/// A pointer moved to an absolute position: [offset] from the corner of the
/// outputs' bounding box.
pub struct ProbeMotion {
    offset: Point<f64, Logical>,
    time: u64,
}

impl Event<ProbeInput> for ProbeMotion {
    fn time(&self) -> u64 {
        self.time
    }

    fn device(&self) -> ProbeDevice {
        ProbeDevice
    }
}

impl AbsolutePositionEvent<ProbeInput> for ProbeMotion {
    fn x(&self) -> f64 {
        self.offset.x
    }

    fn y(&self) -> f64 {
        self.offset.y
    }

    fn x_transformed(&self, _width: i32) -> f64 {
        self.offset.x
    }

    fn y_transformed(&self, _height: i32) -> f64 {
        self.offset.y
    }
}

impl PointerMotionAbsoluteEvent<ProbeInput> for ProbeMotion {}

pub struct ProbeButton {
    code: u32,
    state: ButtonState,
    time: u64,
}

impl Event<ProbeInput> for ProbeButton {
    fn time(&self) -> u64 {
        self.time
    }

    fn device(&self) -> ProbeDevice {
        ProbeDevice
    }
}

impl PointerButtonEvent<ProbeInput> for ProbeButton {
    fn button_code(&self) -> u32 {
        self.code
    }

    fn state(&self) -> ButtonState {
        self.state
    }
}

/// A wheel turned by [horizontal] and [vertical] degrees.
pub struct ProbeAxis {
    horizontal: f64,
    vertical: f64,
    time: u64,
}

impl Event<ProbeInput> for ProbeAxis {
    fn time(&self) -> u64 {
        self.time
    }

    fn device(&self) -> ProbeDevice {
        ProbeDevice
    }
}

impl PointerAxisEvent<ProbeInput> for ProbeAxis {
    fn amount(&self, axis: Axis) -> Option<f64> {
        let amount = match axis {
            Axis::Horizontal => self.horizontal,
            Axis::Vertical => self.vertical,
        };
        (amount != 0.0).then_some(amount)
    }

    fn amount_v120(&self, _axis: Axis) -> Option<f64> {
        None
    }

    fn source(&self) -> AxisSource {
        AxisSource::Wheel
    }

    fn relative_direction(&self, _axis: Axis) -> AxisRelativeDirection {
        AxisRelativeDirection::Identical
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn key_names_map_to_linux_codes() {
        assert_eq!(key_code(&json!("Enter")), Ok(28));
        assert_eq!(key_code(&json!("Arrow Down")), Ok(108));
        assert_eq!(key_code(&json!("super")), Ok(125));
        assert_eq!(key_code(&json!("q")), Ok(16));
        assert_eq!(key_code(&json!(30)), Ok(30));
        assert!(key_code(&json!("NoSuchKey")).is_err());
    }

    #[test]
    fn buttons_and_states_parse() {
        assert_eq!(button_code(&json!("left")), Ok(0x110));
        assert_eq!(button_code(&json!("right")), Ok(0x111));
        assert_eq!(button_code(&json!(0x113)), Ok(0x113));
        assert!(button_code(&json!("thumb")).is_err());
        assert_eq!(pressed(&json!("pressed")), Ok(true));
        assert_eq!(pressed(&json!("released")), Ok(false));
        assert!(pressed(&json!("down")).is_err());
    }

    #[test]
    fn the_socket_lives_in_the_runtime_directory() {
        let path = socket_path("wayland-2");
        if let Some(path) = path {
            assert!(path.ends_with("veshell-probe-wayland-2.sock"));
        }
    }
}
