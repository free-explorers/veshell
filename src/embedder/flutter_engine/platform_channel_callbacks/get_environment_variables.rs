use std::collections::HashMap;

use serde_json::json;

use crate::flutter_engine::wayland_messages::EnvironmentVariables;
use crate::state::State;

use crate::flutter_engine::platform_channels::method_result::MethodResult;

use crate::flutter_engine::platform_channels::method_call::MethodCall;

use crate::backend::Backend;

pub fn get_environment_variables<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let wayland_socket_name = data.wayland_socket_name.as_deref();

    let xwayland_display = data
        .xwayland_state
        .as_mut()
        .map(|state| format!(":{}", state.display));
    let xwayland_display = xwayland_display.as_deref();

    // Environment shared with application launched by the shell.
    // Tracked launches go through the systemd user manager, which has its own
    // session environment, so these values must be forwarded explicitly.
    let environment_variables = HashMap::from([
        ("WAYLAND_DISPLAY", wayland_socket_name),
        ("DISPLAY", xwayland_display),
        ("XDG_CURRENT_DESKTOP", Some("veshell")),
        ("XDG_SESSION_TYPE", Some("wayland")),
        ("GDK_BACKEND", Some("wayland")),
        ("QT_QPA_PLATFORM", Some("wayland")),
    ]);

    data.flutter_engine
        .as_mut()
        .unwrap()
        .set_environment_variables(environment_variables.clone());

    result.success(Some(json!(EnvironmentVariables {
        environment_variables,
    })));
}
