use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct LockAuthRespondPayload {
    response: String,
}

/// The user answered the lock screen's password prompt.
///
/// The payload is not logged: it is the user's secret.
pub fn lock_auth_respond<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let Some(args) = method_call.arguments().cloned() else {
        result.error(
            "invalid_arguments".to_string(),
            "lock_auth_respond requires a response".to_string(),
            None,
        );
        return;
    };
    match serde_json::from_value::<LockAuthRespondPayload>(args) {
        Ok(payload) => {
            crate::lock::respond(data, payload.response);
            result.success(None);
        }
        Err(_) => result.error(
            "invalid_arguments".to_string(),
            "Invalid lock_auth_respond payload".to_string(),
            None,
        ),
    }
}
