use serde_json::Value;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::portal::service::close_shared_session;
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct ScreenCastStopPayload {
    session_handle: String,
}

/// The shell's persistent indicator Stop button: a trusted shell action
/// revoking the capture session (spec 8.3).
pub fn screen_cast_stop<BackendData: Backend + 'static>(
    method_call: MethodCall<Value>,
    mut result: Box<dyn MethodResult<Value>>,
    data: &mut State<BackendData>,
) {
    let payload: ScreenCastStopPayload =
        match serde_json::from_value(method_call.arguments().unwrap().clone()) {
            Ok(payload) => payload,
            Err(error) => {
                result.error(
                    "invalid_screen_cast_stop_payload".to_string(),
                    format!("Screen cast stop payload is invalid: {error}"),
                    None,
                );
                return;
            }
        };
    let Ok(session_handle) = payload.session_handle.try_into() else {
        result.error(
            "invalid_session_handle".to_string(),
            "Session handle is not an object path".to_string(),
            None,
        );
        return;
    };
    close_shared_session(data, &session_handle);
    result.success(None);
}
