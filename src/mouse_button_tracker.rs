use std::collections::{HashMap, HashSet};

use lazy_static::lazy_static;

use crate::flutter_engine::embedder::{
    FlutterPointerMouseButtons_kFlutterPointerButtonMouseBack,
    FlutterPointerMouseButtons_kFlutterPointerButtonMouseForward,
    FlutterPointerMouseButtons_kFlutterPointerButtonMouseMiddle,
    FlutterPointerMouseButtons_kFlutterPointerButtonMousePrimary,
    FlutterPointerMouseButtons_kFlutterPointerButtonMouseSecondary,
};

lazy_static! {
    pub static ref LINUX_TO_FLUTTER_MOUSE_BUTTONS: HashMap<input_linux::Key, u32> = HashMap::from([
        (input_linux::Key::ButtonLeft, FlutterPointerMouseButtons_kFlutterPointerButtonMousePrimary),
        (input_linux::Key::ButtonRight, FlutterPointerMouseButtons_kFlutterPointerButtonMouseSecondary),
        (input_linux::Key::ButtonMiddle, FlutterPointerMouseButtons_kFlutterPointerButtonMouseMiddle),
        (input_linux::Key::ButtonBack, FlutterPointerMouseButtons_kFlutterPointerButtonMouseBack),
        (input_linux::Key::ButtonForward, FlutterPointerMouseButtons_kFlutterPointerButtonMouseForward),
    ]);

    pub static ref FLUTTER_TO_LINUX_MOUSE_BUTTONS: HashMap<u32, input_linux::Key> = HashMap::from([
        (FlutterPointerMouseButtons_kFlutterPointerButtonMousePrimary, input_linux::Key::ButtonLeft),
        (FlutterPointerMouseButtons_kFlutterPointerButtonMouseSecondary, input_linux::Key::ButtonRight),
        (FlutterPointerMouseButtons_kFlutterPointerButtonMouseMiddle, input_linux::Key::ButtonMiddle),
        (FlutterPointerMouseButtons_kFlutterPointerButtonMouseBack, input_linux::Key::ButtonBack),
        (FlutterPointerMouseButtons_kFlutterPointerButtonMouseForward, input_linux::Key::ButtonForward),
    ]);
}

#[derive(Default)]
pub struct MouseButtonTracker {
    down: HashSet<input_linux::Key>,
}

impl MouseButtonTracker {
    pub fn new() -> Self {
        Default::default()
    }

    pub fn is_down(&self, button: input_linux::Key) -> bool {
        self.down.contains(&button)
    }

    pub fn are_any_buttons_pressed(&self) -> bool {
        !self.down.is_empty()
    }

    pub fn press(&mut self, button_code: u16) -> Result<(), input_linux::RangeError> {
        let key = input_linux::Key::from_code(button_code)?;
        self.down.insert(key);
        Ok(())
    }

    pub fn release(&mut self, button_code: u16) -> Result<(), input_linux::RangeError> {
        let key = input_linux::Key::from_code(button_code)?;
        self.down.remove(&key);
        Ok(())
    }

    pub fn get_flutter_button_bitmask(&self) -> i64 {
        let mut flutter_mouse_buttons = 0;
        for button in self.down.iter() {
            if let Some(flutter_button) = LINUX_TO_FLUTTER_MOUSE_BUTTONS.get(button) {
                flutter_mouse_buttons |= flutter_button;
            }
        }
        flutter_mouse_buttons as i64
    }
}
