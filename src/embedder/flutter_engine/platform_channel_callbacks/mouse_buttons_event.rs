use std::time::Duration;

use smithay::backend::input::ButtonState;
use smithay::input::pointer::ButtonEvent;
use tracing::info;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::mouse_button_tracker::FLUTTER_TO_LINUX_MOUSE_BUTTONS;
use crate::state::State;
use smithay::utils::SERIAL_COUNTER;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct MouseButtonsPayload {
    surface_id: u64,
    buttons: Vec<Button>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct Button {
    button: u32,
    is_pressed: bool,
}

pub fn mouse_buttons_event<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let now = Duration::from(data.clock.now()).as_millis() as u32;
    let pointer = data.pointer.clone();

    let args = method_call.arguments().unwrap().clone();
    let payload: MouseButtonsPayload = serde_json::from_value(args).unwrap();
    info!("mouse_buttons_event: for  {:?}", payload.surface_id);

    //

    for button in payload.buttons {
        pointer.button(
            data,
            &ButtonEvent {
                serial: SERIAL_COUNTER.next_serial(),
                time: now,
                button: *FLUTTER_TO_LINUX_MOUSE_BUTTONS.get(&button.button).unwrap() as u32,
                state: if button.is_pressed {
                    ButtonState::Pressed
                } else {
                    ButtonState::Released
                },
            },
        );
    }

    pointer.frame(data);
    result.success(None);
}
