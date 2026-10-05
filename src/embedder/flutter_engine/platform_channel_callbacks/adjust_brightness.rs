use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;

use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct AdjustBrightnessPayload {
    /// Signed fraction of full brightness, e.g. `0.05` or `-0.05`.
    delta: f32,
}

/// Move the display backlight by the requested fraction. The shell sends this
/// when a brightness hotkey fires; clamping and the "never fully off" floor
/// live in [`crate::brightness::Brightness`].
pub fn adjust_brightness<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let Some(args) = method_call.arguments().cloned() else {
        result.error(
            "invalid_arguments".to_string(),
            "adjust_brightness requires a delta".to_string(),
            None,
        );
        return;
    };
    match serde_json::from_value::<AdjustBrightnessPayload>(args) {
        Ok(payload) => {
            data.brightness.adjust(payload.delta);
            result.success(None);
        }
        Err(error) => result.error(
            "invalid_arguments".to_string(),
            format!("Invalid adjust_brightness payload: {error}"),
            None,
        ),
    }
}
