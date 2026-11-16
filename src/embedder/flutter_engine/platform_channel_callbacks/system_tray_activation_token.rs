use serde_json::{json, Value};

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct ActivationTokenPayload {
    /// The watcher id of the item the user activated.
    id: String,
}

/// The user activated a tray item: mint a trusted activation token and answer
/// it, so the shell can hand it to the item (`ProvideXdgActivationToken`)
/// before `Activate`.
///
/// The token names no window: the application decides which window it shows,
/// and whichever surface it activates with the token is focused and brought
/// into view instead of being read as a demand for attention. Applications
/// that cannot take the token activate with one of their own: the item's
/// process is granted that activation for a moment too.
pub fn system_tray_activation_token<BackendData: Backend + 'static>(
    method_call: MethodCall<Value>,
    mut result: Box<dyn MethodResult<Value>>,
    data: &mut State<BackendData>,
) {
    let payload: ActivationTokenPayload =
        match serde_json::from_value(method_call.arguments().cloned().unwrap_or_default()) {
            Ok(payload) => payload,
            Err(error) => {
                result.error(
                    "invalid_system_tray_activation_token".to_string(),
                    format!("System tray activation token payload is invalid: {error}"),
                    None,
                );
                return;
            }
        };
    if let Some(pid) = data.system_tray_state.item_pid(&payload.id) {
        data.system_tray_state.grant_activation(pid);
    }
    let token = data.mint_trusted_activation_token(None);
    result.success(Some(json!(token)));
}
