use serde_json::Value;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct ActionInvokedPayload {
    id: u32,
    action_key: String,
}

/// The shell invoked an action: emit `ActionInvoked(id, actionKey)`.
pub fn notification_action_invoked<BackendData: Backend + 'static>(
    method_call: MethodCall<Value>,
    mut result: Box<dyn MethodResult<Value>>,
    data: &mut State<BackendData>,
) {
    let payload: ActionInvokedPayload =
        match serde_json::from_value(method_call.arguments().unwrap().clone()) {
            Ok(payload) => payload,
            Err(error) => {
                result.error(
                    "invalid_action_invoked".to_string(),
                    format!("Action invoked payload is invalid: {error}"),
                    None,
                );
                return;
            }
        };
    data.notification_state
        .emit_action_invoked(payload.id, &payload.action_key);
    result.success(None);
}
