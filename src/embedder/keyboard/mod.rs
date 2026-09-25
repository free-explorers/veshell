use std::collections::{HashMap, HashSet};
use std::sync::atomic::Ordering;
use std::time::Duration;

use smithay::backend::input::KeyState;
use smithay::backend::session::Session;
use smithay::input::keyboard::ModifiersState;
use smithay::utils::SERIAL_COUNTER;
use tracing::{error, info};
use xkbcommon::xkb::{Keycode, Keysym};

use crate::backend::Backend;
use crate::state::State;

pub mod key_mapping;
pub mod key_repeater;

#[derive(Copy, Clone)]
pub struct VeshellKeyEvent {
    pub key_code: Keycode,
    pub raw_keysym: Option<Keysym>,
    pub keysym: Keysym,
    pub state: KeyState,
    pub time: u32,
    pub mods: ModifiersState,
    pub mods_changed: bool,
    pub synthesized: bool,
}

#[derive(Default)]
pub struct SuperKeyForwarding {
    // Flutter sees these immediately; clients only see them once the shortcut is resolved.
    pending: Vec<VeshellKeyEvent>,
    consumed: HashMap<Keycode, VeshellKeyEvent>,
    forwarded: HashSet<Keycode>,
}

impl SuperKeyForwarding {
    fn resolve(&mut self, event: VeshellKeyEvent, handled: bool) -> Vec<VeshellKeyEvent> {
        if event.state == KeyState::Released {
            if self.forwarded.remove(&event.key_code) {
                self.consumed.remove(&event.key_code);
                return vec![event];
            }
            if self.consumed.remove(&event.key_code).is_some() {
                return Vec::new();
            }
        }

        if handled {
            self.consume_pending();
            if event.state == KeyState::Pressed {
                self.consumed.insert(event.key_code, event);
            }
            return Vec::new();
        }

        let is_super = matches!(event.keysym, Keysym::Super_L | Keysym::Super_R);
        if self.pending.is_empty() {
            if is_super && event.state == KeyState::Pressed {
                self.pending.push(event);
                return Vec::new();
            }
            if is_super && event.state == KeyState::Released {
                return Vec::new();
            }
            if event.state == KeyState::Pressed && !Self::is_modifier(event.keysym) {
                let mut modifiers: Vec<_> = self
                    .consumed
                    .values()
                    .copied()
                    .filter(|down| Self::is_modifier(down.keysym))
                    .collect();
                modifiers.sort_by_key(|down| down.time);
                if !modifiers.is_empty() {
                    for down in &modifiers {
                        self.consumed.remove(&down.key_code);
                        self.track_forwarded(*down);
                    }
                    self.track_forwarded(event);
                    modifiers.push(event);
                    return modifiers;
                }
            }
            self.track_forwarded(event);
            return vec![event];
        }

        // A key already held before Super is unrelated to this shortcut sequence.
        if event.state == KeyState::Released
            && !self
                .pending
                .iter()
                .any(|down| down.key_code == event.key_code && down.state == KeyState::Pressed)
        {
            return vec![event];
        }

        self.pending.push(event);
        if Self::is_modifier(event.keysym) && !(is_super && event.state == KeyState::Released) {
            return Vec::new();
        }

        let events = std::mem::take(&mut self.pending);
        for event in &events {
            self.track_forwarded(*event);
        }
        events
    }

    fn is_modifier(keysym: Keysym) -> bool {
        matches!(
            keysym,
            Keysym::Super_L
                | Keysym::Super_R
                | Keysym::Shift_L
                | Keysym::Shift_R
                | Keysym::Control_L
                | Keysym::Control_R
                | Keysym::Alt_L
                | Keysym::Alt_R
                | Keysym::Meta_L
                | Keysym::Meta_R
                | Keysym::ISO_Level3_Shift
        )
    }

    fn clear(&mut self) {
        self.pending.clear();
        self.consumed.clear();
        self.forwarded.clear();
    }

    fn consume_pending(&mut self) {
        for event in self.pending.drain(..) {
            match event.state {
                KeyState::Pressed => {
                    self.consumed.insert(event.key_code, event);
                }
                KeyState::Released => {
                    self.consumed.remove(&event.key_code);
                }
            }
        }
    }

    fn track_forwarded(&mut self, event: VeshellKeyEvent) {
        match event.state {
            KeyState::Pressed => {
                self.forwarded.insert(event.key_code);
            }
            KeyState::Released => {
                self.forwarded.remove(&event.key_code);
            }
        }
    }
}

pub fn swap_left_alt_and_meta<BackendData: Backend + 'static>(
    data: &mut State<BackendData>,
    key_code: Keycode,
) -> Keycode {
    let swap_alt_and_win = data
        .settings_manager
        .get_settings()
        .keyboard
        .swap_alt_and_win;
    info!("swap_alt_and_win: {}", swap_alt_and_win);
    if swap_alt_and_win {
        let mut linux_code = key_code.raw() - 8;
        if data.meta_window_state.meta_window_in_gaming_mode.is_none() {
            // Swap Meta ant leftAlt keycode
            if linux_code == input_linux::sys::KEY_LEFTMETA as u32 {
                info!("keycode is meta replace by leftalt");
                linux_code = input_linux::sys::KEY_LEFTALT as u32
            } else if linux_code == input_linux::sys::KEY_LEFTALT as u32 {
                info!("keycode is leftalt replace by leftmeta ");
                linux_code = input_linux::sys::KEY_LEFTMETA as u32
            }
        }
        Keycode::new(linux_code + 8)
    } else {
        key_code
    }
}

pub fn handle_keyboard_event<BackendData: Backend + 'static>(
    data: &mut State<BackendData>,
    mut key_code: Keycode,
    state: KeyState,
    time: u32,
    synthesized: bool,
) {
    // Update the state of the keyboard.
    // Every key event must be passed through `glfw_key_codes.input_intercept`
    // so that Smithay knows what keys are pressed.
    let keyboard = data.keyboard.clone();
    key_code = swap_left_alt_and_meta(data, key_code);

    // 1. Update the Smithay keyboard state but intercept the event so it's not forwarded to the focused client just yet
    let ((mods, raw_keysym, keysym), mods_changed) =
        keyboard.input_intercept::<_, _>(data, key_code, state, |_, mods, keysym_handle| {
            // 2. Retrieve the keysym and modifiers with the xkb layout applied
            (
                *mods,
                keysym_handle.raw_latin_sym_or_raw_current_sym(),
                keysym_handle.modified_sym(),
            )
        });

    info!(
        ?state,
        mods = ?mods,
        keysym = ::xkbcommon::xkb::keysym_get_name(keysym),
        "keysym",
    );

    let veshell_key_event = VeshellKeyEvent {
        key_code,
        raw_keysym,
        keysym,
        state,
        time,
        mods,
        mods_changed,
        synthesized,
    };

    // 3. Check if the keystroke result in compositor hotkeys shortcuts
    if handle_embedder_hotkeys(data, veshell_key_event) {
        data.super_key_forwarding.consume_pending();
        return;
    }

    if data.meta_window_state.meta_window_in_gaming_mode.is_some() {
        keyboard.input_forward(
            data,
            key_code,
            state,
            SERIAL_COUNTER.next_serial(),
            time,
            mods_changed,
        );
        return;
    }

    data.flutter_engine
        .as_mut()
        .unwrap()
        .send_key_event(veshell_key_event, false)
        .expect("Failed to send key event to Flutter");

    // Track what Flutter believes is held: every press is remembered and
    // its release retires it. The capture-session branch replays a
    // swallowed release whose press already arrived here so the pairing
    // survives a selection that starts with a modifier held.
    match veshell_key_event.state {
        KeyState::Pressed => {
            data.flutter_sent_keys.insert(key_code, veshell_key_event);
        }
        KeyState::Released => {
            data.flutter_sent_keys.remove(&key_code);
        }
    }

    // Initiate key repeat.
    // The callback that gets called repeatedly is defined in the constructor of `State`.
    // Modifier keys do nothing on their own, so it doesn't make sense to repeat them.
    // TODO: It would be nice to be able to define the callback here next to this block of code
    // because asynchronous flows like this one are difficult to follow.
    if !mods_changed {
        match state {
            KeyState::Pressed => {
                data.key_repeater.down(
                    veshell_key_event,
                    Duration::from_millis(data.repeat_delay),
                    Duration::from_millis(data.repeat_rate),
                );
            }
            KeyState::Released => {
                data.key_repeater.up(veshell_key_event);
            }
        }
    }
}

fn handle_embedder_hotkeys<BackendData: Backend + 'static>(
    data: &mut State<BackendData>,
    event: VeshellKeyEvent,
) -> bool {
    // While a recording runs, the desktop stays live and input flows
    // normally; Print is the only finisher the user controls (Escape and
    // clicks are never a stop action). The recording also finalizes on
    // layout changes from its pump.
    if data.capture_state.recording_session.is_some() {
        if event.state == KeyState::Pressed && event.keysym == Keysym::Print {
            crate::capture::stop_recording(data, "user stop");
        }
        return false;
    }

    // While a screenshot session runs, the desktop must stay frozen: keys
    // are swallowed and never forwarded to a client. One exception keeps
    // the Flutter key state consistent: a release for a press that was
    // already sent to Flutter gets its matching keyup synthesized too,
    // otherwise Flutter keeps believing that key is held (which froze the
    // shell hotkeys after selection sessions).
    if data.capture_state.session.is_some() {
        if event.state == KeyState::Released {
            if data.flutter_sent_keys.remove(&event.key_code).is_some() {
                data.flutter_engine
                    .as_mut()
                    .unwrap()
                    .send_key_event(event, false)
                    .expect("Failed to send pending key release to Flutter");
            }
        }
        if event.keysym == Keysym::Escape && event.state == KeyState::Pressed {
            crate::capture::cancel_capture_session(data);
        }
        return true;
    }

    // Capture the exact rendering state at the moment the hotkey is
    // pressed: Rust owns the whole flow, the key never reaches Flutter.
    // Shift+Print records the dragged area live; plain Print takes a
    // screenshot.
    if event.keysym == Keysym::Print && event.state == KeyState::Pressed {
        let pointer_location = data.pointer.current_location();
        crate::capture::begin_capture_session(data, pointer_location, event.mods.shift);
        return true;
    }

    // Switching to another VT
    if (Keysym::XF86_Switch_VT_1.raw()..=Keysym::XF86_Switch_VT_12.raw())
        .contains(&event.keysym.raw())
    {
        if let Err(_err) = data
            .backend_data
            .get_session()
            .change_vt((event.keysym.raw() - Keysym::XF86_Switch_VT_1.raw() + 1) as i32)
        {
            error!("Failed switching virtual terminal.");
        }
        return true;
    }

    // Exiting the compositor
    if event.keysym == Keysym::Escape && event.mods.alt {
        data.running.store(false, Ordering::SeqCst);
        return true;
    }

    // disable gaming mode
    if event.keysym == Keysym::Escape && event.mods.ctrl {
        if let Some(meta_window_id) = data.meta_window_state.meta_window_in_gaming_mode.clone() {
            data.patch_meta_window(
                crate::meta_window_state::meta_window::MetaWindowPatch::UpdateGameModeActivated {
                    id: meta_window_id,
                    value: false,
                },
                true,
            );
        }
        return true;
    }

    return false;
}

pub fn post_flutter_handle_key_event<BackendData: Backend + 'static>(
    data: &mut State<BackendData>,
    event: VeshellKeyEvent,
    handled: bool,
) {
    let text_input = &mut data.flutter_engine.as_mut().unwrap().text_input;
    if text_input.is_active() {
        data.super_key_forwarding.clear();
        if !handled && event.state == KeyState::Pressed && !event.mods.ctrl && !event.mods.alt {
            text_input.press_key(event.keysym);
        }
        // It doesn't matter if the text field captured the key event or not.
        // As long as it stays active, don't forward events to the Wayland client.
        return;
    }

    // Replay an unhandled prefix before its chord key, or drop a handled sequence.
    let keyboard = data.keyboard.clone();
    for client_event in data.super_key_forwarding.resolve(event, handled) {
        keyboard.input_forward(
            data,
            client_event.key_code,
            client_event.state,
            SERIAL_COUNTER.next_serial(),
            client_event.time,
            client_event.mods_changed,
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn key(key_code: u32, keysym: Keysym, state: KeyState) -> VeshellKeyEvent {
        VeshellKeyEvent {
            key_code: Keycode::new(key_code),
            raw_keysym: Some(keysym),
            keysym,
            state,
            time: 0,
            mods: ModifiersState::default(),
            mods_changed: false,
            synthesized: false,
        }
    }

    #[test]
    fn overview_tap_never_reaches_client() {
        let mut forwarding = SuperKeyForwarding::default();
        let down = key(133, Keysym::Super_L, KeyState::Pressed);
        let up = key(133, Keysym::Super_L, KeyState::Released);
        assert!(forwarding.resolve(down, false).is_empty());
        assert!(forwarding.resolve(up, true).is_empty());
        assert!(forwarding.pending.is_empty());
    }

    #[test]
    fn unhandled_super_chord_forwards_modifier_first() {
        let mut forwarding = SuperKeyForwarding::default();
        let down = key(133, Keysym::Super_L, KeyState::Pressed);
        let up = key(133, Keysym::Super_L, KeyState::Released);
        let chord = key(38, Keysym::a, KeyState::Pressed);
        assert!(forwarding.resolve(down, false).is_empty());
        let events = forwarding.resolve(chord, false);
        assert_eq!(events.len(), 2);
        assert_eq!(events[0].key_code, down.key_code);
        assert_eq!(events[1].key_code, chord.key_code);
        assert_eq!(forwarding.resolve(up, false).len(), 1);
    }

    #[test]
    fn configured_super_chords_consume_press_and_release() {
        for (code, symbol) in [
            (25, Keysym::w),
            (39, Keysym::s),
            (40, Keysym::d),
            (38, Keysym::a),
            (24, Keysym::q),
        ] {
            let mut forwarding = SuperKeyForwarding::default();
            let super_down = key(133, Keysym::Super_L, KeyState::Pressed);
            let super_up = key(133, Keysym::Super_L, KeyState::Released);
            let chord_down = key(code, symbol, KeyState::Pressed);
            let chord_up = key(code, symbol, KeyState::Released);
            assert!(forwarding.resolve(super_down, false).is_empty());
            assert!(forwarding.resolve(chord_down, true).is_empty());
            assert!(forwarding.resolve(chord_up, false).is_empty());
            assert!(forwarding.resolve(super_up, false).is_empty());
        }
    }

    #[test]
    fn unhandled_super_tap_forwards_both_events() {
        let mut forwarding = SuperKeyForwarding::default();
        let down = key(133, Keysym::Super_L, KeyState::Pressed);
        let up = key(133, Keysym::Super_L, KeyState::Released);
        assert!(forwarding.resolve(down, false).is_empty());
        let events = forwarding.resolve(up, false);
        assert_eq!(events.len(), 2);
        assert_eq!(events[0].state, KeyState::Pressed);
        assert_eq!(events[1].state, KeyState::Released);
    }

    #[test]
    fn consumed_super_press_does_not_forward_its_release() {
        let mut forwarding = SuperKeyForwarding::default();
        let down = key(133, Keysym::Super_L, KeyState::Pressed);
        let up = key(133, Keysym::Super_L, KeyState::Released);
        assert!(forwarding.resolve(down, true).is_empty());
        assert!(forwarding.resolve(up, false).is_empty());
    }

    #[test]
    fn shifted_host_chord_does_not_leak_any_keys() {
        let mut forwarding = SuperKeyForwarding::default();
        let super_down = key(133, Keysym::Super_L, KeyState::Pressed);
        let shift_down = key(50, Keysym::Shift_L, KeyState::Pressed);
        let shift_up = key(50, Keysym::Shift_L, KeyState::Released);
        let chord_down = key(25, Keysym::w, KeyState::Pressed);
        let chord_up = key(25, Keysym::w, KeyState::Released);
        let super_up = key(133, Keysym::Super_L, KeyState::Released);
        for (event, handled) in [
            (super_down, false),
            (shift_down, false),
            (chord_down, true),
            (chord_up, false),
            (shift_up, false),
            (super_up, false),
        ] {
            assert!(forwarding.resolve(event, handled).is_empty());
        }
    }

    #[test]
    fn unhandled_shifted_chord_replays_prefix_in_order() {
        let mut forwarding = SuperKeyForwarding::default();
        let super_down = key(133, Keysym::Super_L, KeyState::Pressed);
        let shift_down = key(50, Keysym::Shift_L, KeyState::Pressed);
        let chord_down = key(25, Keysym::w, KeyState::Pressed);
        assert!(forwarding.resolve(super_down, false).is_empty());
        assert!(forwarding.resolve(shift_down, false).is_empty());
        let events = forwarding.resolve(chord_down, false);
        assert_eq!(events.len(), 3);
        assert_eq!(events[0].key_code, super_down.key_code);
        assert_eq!(events[1].key_code, shift_down.key_code);
        assert_eq!(events[2].key_code, chord_down.key_code);
        assert_eq!(
            forwarding
                .resolve(key(50, Keysym::Shift_L, KeyState::Released), true)
                .len(),
            1
        );
    }

    #[test]
    fn later_unhandled_chord_replays_held_super_after_host_shortcut() {
        let mut forwarding = SuperKeyForwarding::default();
        let super_down = key(133, Keysym::Super_L, KeyState::Pressed);
        let host_down = key(25, Keysym::w, KeyState::Pressed);
        let client_down = key(52, Keysym::z, KeyState::Pressed);
        forwarding.resolve(super_down, false);
        forwarding.resolve(host_down, true);
        assert!(forwarding
            .resolve(key(25, Keysym::w, KeyState::Released), false)
            .is_empty());
        let events = forwarding.resolve(client_down, false);
        assert_eq!(events.len(), 2);
        assert_eq!(events[0].key_code, super_down.key_code);
        assert_eq!(events[1].key_code, client_down.key_code);
        assert_eq!(
            forwarding
                .resolve(key(133, Keysym::Super_L, KeyState::Released), false)
                .len(),
            1
        );
    }
}
