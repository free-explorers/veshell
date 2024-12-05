use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::focus::PointerFocusTarget;
use crate::state::State;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct Offset {
    x: f64,
    y: f64,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct PointerFocus {
    surface_id: u64,
    global_offset: Offset,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct PointerFocusMessage {
    focus: Option<PointerFocus>,
}

pub fn pointer_focus<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: PointerFocusMessage = serde_json::from_value(args).unwrap();

    if let Some(pointer_focus) = payload.focus {
        data.surface_id_under_cursor = Some(pointer_focus.surface_id);
        if let Some(surface) = data.surfaces.get(&pointer_focus.surface_id) {
            if let Some(x11_surface) = data.x11_surface_per_wl_surface.get(surface).cloned() {
                let _ = data.x11_wm.as_mut().unwrap().raise_window(&x11_surface);
            }
            data.pointer_focus = Some((
                PointerFocusTarget::from(surface),
                (pointer_focus.global_offset.x, pointer_focus.global_offset.y).into(),
            ));
        }
    } else {
        data.surface_id_under_cursor = None;
        data.pointer_focus = None;
    }
    result.success(None);
}
