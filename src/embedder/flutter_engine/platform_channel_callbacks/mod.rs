use smithay::reexports::calloop::channel::Event;
use smithay::reexports::calloop::channel::Event::Msg;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;

use crate::state::State;

mod activate_window;
mod close_window;
mod get_environment_variables;
mod get_monitor_layout;
mod meta_window_patches;
mod mouse_buttons_event;
mod on_shell_ready;
mod pointer_exit;
mod pointer_focus;
mod resize_window;

use self::activate_window::activate_window;
use self::close_window::close_window;
use self::get_environment_variables::get_environment_variables;
use self::get_monitor_layout::get_monitor_layout;
use self::meta_window_patches::meta_window_patches;
use self::mouse_buttons_event::mouse_buttons_event;
use self::on_shell_ready::on_shell_ready;
use self::pointer_exit::pointer_exit;
use self::pointer_focus::pointer_focus;
use self::resize_window::resize_window;

pub fn platform_channel_method_handler<BackendData: Backend + 'static>(
    event: Event<(
        MethodCall<serde_json::Value>,
        Box<dyn MethodResult<serde_json::Value>>,
    )>,
    _: &mut (),
    data: &mut State<BackendData>,
) {
    if let Msg((method_call, mut result)) = event {
        match method_call.method() {
            "pointer_exit" => pointer_exit(method_call, result, data),
            "pointer_focus" => pointer_focus(method_call, result, data),
            "mouse_buttons_event" => mouse_buttons_event(method_call, result, data),
            "activate_window" => activate_window(method_call, result, data),
            "resize_window" => resize_window(method_call, result, data),
            "close_window" => close_window(method_call, result, data),
            "get_monitor_layout" => get_monitor_layout(method_call, result, data),
            "get_environment_variables" => get_environment_variables(method_call, result, data),
            "meta_window_patches" => meta_window_patches(method_call, result, data),
            "shell_ready" => on_shell_ready(method_call, result, data),
            _ => result.error(
                "method_not_found".to_string(),
                format!("Method {} not found", method_call.method()),
                None,
            ),
        }
    }
}
