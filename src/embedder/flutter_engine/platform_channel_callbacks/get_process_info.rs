use serde::Deserialize;
use serde_json::json;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::meta_window_state::process_info::ProcessInfo;
use crate::state::State;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GetProcessInfoPayload {
    pid: i32,
}

/// Returns a fresh `/proc` snapshot for [pid].
///
/// The shell polls this for displayed tiles: cwd, command line and a terminal's
/// shell/foreground job can change while the window lives, and process-info
/// events are otherwise only emitted on window lifecycle changes.
pub fn get_process_info<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    _data: &mut State<BackendData>,
) {
    let Some(arguments) = method_call.arguments().cloned() else {
        result.error(
            "missing_arguments".to_string(),
            "pid is required".to_string(),
            None,
        );
        return;
    };
    let payload = match serde_json::from_value::<GetProcessInfoPayload>(arguments) {
        Ok(payload) => payload,
        Err(error) => {
            result.error("invalid_arguments".to_string(), error.to_string(), None);
            return;
        }
    };
    if payload.pid <= 0 {
        result.error(
            "invalid_pid".to_string(),
            "pid must be positive".to_string(),
            None,
        );
        return;
    }

    result.success(Some(json!(ProcessInfo::for_pid(payload.pid))));
}
