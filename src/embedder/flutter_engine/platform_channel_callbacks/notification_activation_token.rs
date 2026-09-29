use serde_json::Value;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct ActivationTokenPayload {
    id: u32,
    meta_window_id: String,
}

/// The shell invoked a notification action: mint an activation token for its
/// target window and emit `ActivationToken(id, token)` so the sender can
/// activate its own toplevel.
///
/// The token is remembered as trusted for `meta_window_id`: when the client
/// turns it into an `xdg_activation_v1` request, the window is focused instead
/// of being read as a demand for attention.
pub fn notification_activation_token<BackendData: Backend + 'static>(
    method_call: MethodCall<Value>,
    mut result: Box<dyn MethodResult<Value>>,
    data: &mut State<BackendData>,
) {
    let payload: ActivationTokenPayload =
        match serde_json::from_value(method_call.arguments().unwrap().clone()) {
            Ok(payload) => payload,
            Err(error) => {
                result.error(
                    "invalid_activation_token".to_string(),
                    format!("Activation token payload is invalid: {error}"),
                    None,
                );
                return;
            }
        };

    let token = data.mint_notification_activation_token(&payload.meta_window_id);
    data.notification_state
        .emit_activation_token(payload.id, &token);
    result.success(None);
}
