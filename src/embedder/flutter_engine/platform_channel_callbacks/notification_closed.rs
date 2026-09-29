use serde_json::Value;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct ClosedPayload {
    id: u32,
    reason: u32,
}

/// The shell closed a notification: emit `NotificationClosed(id, reason)`.
///
/// The shell decides whether a signal is due (idempotent close), so Rust emits
/// exactly when asked.
pub fn notification_closed<BackendData: Backend + 'static>(
    method_call: MethodCall<Value>,
    mut result: Box<dyn MethodResult<Value>>,
    data: &mut State<BackendData>,
) {
    let payload: ClosedPayload =
        match serde_json::from_value(method_call.arguments().unwrap().clone()) {
            Ok(payload) => payload,
            Err(error) => {
                result.error(
                    "invalid_notification_closed".to_string(),
                    format!("Notification closed payload is invalid: {error}"),
                    None,
                );
                return;
            }
        };
    data.notification_state
        .emit_notification_closed(payload.id, payload.reason);
    data.notification_state.forget_notification(payload.id);
    result.success(None);
}
