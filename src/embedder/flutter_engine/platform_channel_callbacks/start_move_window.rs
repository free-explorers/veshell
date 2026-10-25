use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct StartMoveWindowPayload {
    meta_window_id: String,
}

/// Starts a compositor-owned move for a floating window.
///
/// Only the floating escape hatch uses this. The compositor tracks the pointer
/// and publishes the placement for both X11 and Wayland; the shell follows the
/// model. A tiled or maximized window is ignored.
pub fn start_move_window<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: StartMoveWindowPayload = serde_json::from_value(args).unwrap();
    let pointer = data.pointer.current_location();
    data.start_floating_move(payload.meta_window_id, pointer);
    result.success(None);
}
