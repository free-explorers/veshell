use serde_json::Value;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct NotifyResultPayload {
    call_token: u64,
    id: u32,
}

/// The shell's answer to a forwarded `Notify`: the id it assigned. Completes
/// the pending D-Bus reply for that call token.
pub fn notification_notify_result<BackendData: Backend + 'static>(
    method_call: MethodCall<Value>,
    mut result: Box<dyn MethodResult<Value>>,
    data: &mut State<BackendData>,
) {
    let payload: NotifyResultPayload =
        match serde_json::from_value(method_call.arguments().unwrap().clone()) {
            Ok(payload) => payload,
            Err(error) => {
                result.error(
                    "invalid_notification_result".to_string(),
                    format!("Notification result payload is invalid: {error}"),
                    None,
                );
                return;
            }
        };
    data.notification_state
        .complete_notify(payload.call_token, payload.id);
    result.success(None);
}
