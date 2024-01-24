use smithay::backend::input::KeyState;
use smithay::input::keyboard::ModifiersState;

pub mod glfw_key_codes;
pub mod key_repeater;

#[derive(Copy, Clone)]
pub struct KeyEvent {
    pub key_code: u32,
    pub codepoint: Option<char>,
    pub state: KeyState,
    pub time: u32,
    pub mods: ModifiersState,
    pub mods_changed: bool,
}
