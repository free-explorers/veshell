use serde::Deserialize;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::meta_window_state::meta_resize_edge::MetaResizeEdge;
use crate::state::State;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct StartResizeWindowPayload {
    meta_window_id: String,
    edge: u32,
}

/// Starts a compositor-owned resize for a floating window.
///
/// The shell keeps the visual resize affordances; Rust owns the pointer while
/// the edge is dragged and publishes the resulting rect. Tiled/maximized
/// windows are rejected by `start_floating_resize`.
pub fn start_resize_window<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: StartResizeWindowPayload = serde_json::from_value(args).unwrap();
    let Some(edge) = MetaResizeEdge::from_bits(payload.edge) else {
        result.success(None);
        return;
    };
    let pointer = data.pointer.current_location();
    data.start_floating_resize(payload.meta_window_id, edge, pointer);
    result.success(None);
}
