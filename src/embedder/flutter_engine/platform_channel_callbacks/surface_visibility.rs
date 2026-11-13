use std::collections::HashSet;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
pub(crate) struct SurfaceVisibilityPayload {
    pub(crate) visible: Vec<u64>,
    pub(crate) limited: Vec<u64>,
}

/// The shell reports which client surfaces it displays, at full rate or
/// limited (a paused game); every other surface is hidden. See
/// `crate::surface_pacing`.
pub fn surface_visibility<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let payload = method_call
        .arguments()
        .cloned()
        .and_then(|args| serde_json::from_value::<SurfaceVisibilityPayload>(args).ok());
    let Some(payload) = payload else {
        result.error(
            "invalid_arguments".to_string(),
            "surface_visibility expects visible and limited surface ids".to_string(),
            None,
        );
        return;
    };
    data.set_surface_visibility(
        payload.visible.into_iter().collect::<HashSet<_>>(),
        payload.limited.into_iter().collect::<HashSet<_>>(),
    );
    result.success(None);
}
