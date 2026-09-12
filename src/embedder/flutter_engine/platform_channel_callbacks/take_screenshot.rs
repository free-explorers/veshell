use serde_json::json;

use crate::backend::Backend;
use crate::capture::{
    prepare_desktop_area_screenshot, queue_prepared_screenshot, PreparedScreenshotRequest,
    ScreenshotRequest,
};
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

pub fn take_screenshot<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let request = method_call
        .arguments()
        .ok_or_else(|| "Prepared screenshot ID is required".to_string())
        .and_then(|arguments| {
            serde_json::from_value::<PreparedScreenshotRequest>(arguments.clone())
                .map_err(|error| format!("Invalid prepared screenshot ID: {error}"))
        });

    match request {
        Ok(request) => queue_prepared_screenshot(data, request.id, result),
        Err(message) => result.error("screenshot_failed".to_string(), message, None),
    }
}

pub fn prepare_screenshot<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let request = method_call
        .arguments()
        .ok_or_else(|| "Screenshot rectangle is required".to_string())
        .and_then(|arguments| {
            serde_json::from_value::<ScreenshotRequest>(arguments.clone())
                .map_err(|error| format!("Invalid screenshot rectangle: {error}"))
        });

    match request
        .and_then(|request| prepare_desktop_area_screenshot(data, request.rect, request.revision))
    {
        Ok(id) => result.success(Some(json!({ "id": id }))),
        Err(message) => result.error("screenshot_failed".to_string(), message, None),
    }
}
