use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;

use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct SetNightLightPayload {
    enabled: bool,
}

/// The Helm's Night Light toggle. It overrides the schedule until its next
/// transition; see [`crate::night_light`].
pub fn set_night_light<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let payload = method_call
        .arguments()
        .cloned()
        .ok_or_else(|| "set_night_light requires `enabled`".to_owned())
        .and_then(|args| {
            serde_json::from_value::<SetNightLightPayload>(args)
                .map_err(|error| format!("Invalid set_night_light payload: {error}"))
        });
    match payload {
        Ok(payload) => {
            crate::night_light::set_enabled(data, payload.enabled);
            result.success(None);
        }
        Err(message) => result.error("invalid_arguments".to_string(), message, None),
    }
}
