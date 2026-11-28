use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;

use crate::state::{BrightnessChangeSource, State};

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct SetBrightnessPayload {
    /// Fraction of full brightness, in `0.0..1.0`.
    fraction: f32,
}

/// Set the display backlight to the requested level: the Helm's brightness
/// slider. The "never fully off" floor lives in
/// [`crate::brightness::Brightness`]. Reported back without the OSD, which
/// would only cover the slider being dragged.
pub fn set_brightness<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let payload = method_call
        .arguments()
        .cloned()
        .ok_or_else(|| "set_brightness requires a fraction".to_owned())
        .and_then(|args| {
            serde_json::from_value::<SetBrightnessPayload>(args)
                .map_err(|error| format!("Invalid set_brightness payload: {error}"))
        });
    match payload {
        Ok(payload) => {
            data.brightness.set(payload.fraction);
            data.notify_brightness_changed(BrightnessChangeSource::Helm);
            result.success(None);
        }
        Err(message) => result.error("invalid_arguments".to_string(), message, None),
    }
}
