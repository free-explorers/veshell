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
    };

    // 3. Check if the keystroke result in compositor hotkeys shortcuts
    if handle_embedder_hotkeys(data, veshell_key_event) {
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
    if handled {
        // Flutter consumed this event. Probably a keyboard shortcut.
        return;
    }

    let text_input = &mut data.flutter_engine.as_mut().unwrap().text_input;
    if text_input.is_active() {
        if event.state == KeyState::Pressed && !event.mods.ctrl && !event.mods.alt {
            text_input.press_key(event.keysym);
        }
        // It doesn't matter if the text field captured the key event or not.
        // As long as it stays active, don't forward events to the Wayland client.
        return;
    }

    // The compositor was not interested in this event,
    // so we forward it to the Wayland client in focus if there is one.
    let keyboard = data.keyboard.clone();
    keyboard.input_forward(
        data,
        event.key_code,
        event.state,
        SERIAL_COUNTER.next_serial(),
        event.time,
        event.mods_changed,
    );
}
