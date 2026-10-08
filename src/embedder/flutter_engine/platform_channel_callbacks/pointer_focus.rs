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
    // While a game owns the input the compositor keeps the pointer focus it set
    // on activation. The shell swaps the surface for a placeholder (and the
    // fullscreen route covers the tile), which fires a surface exit; letting
    // that through would clear the focus and the game would stop receiving
    // motion and buttons.
    if data.meta_window_state.meta_window_in_gaming_mode.is_some() {
        tracing::debug!("ignoring pointer focus change while a game owns the input");
        result.success(None);
        return;
    }

    let args = method_call.arguments().unwrap().clone();
    let payload: PointerFocusMessage = serde_json::from_value(args).unwrap();

    if let Some(pointer_focus) = payload.focus {
        data.surface_id_under_cursor = Some(pointer_focus.surface_id);
        if let Some(surface) = data.surfaces.get(&pointer_focus.surface_id).cloned() {
            if let Some(x11_surface) = data.x11_surface_per_wl_surface.get(&surface).cloned() {
                let _ = data
                    .xwayland_state
                    .as_mut()
                    .unwrap()
                    .xwm
                    .as_mut()
                    .unwrap()
                    .raise_window(&x11_surface);
            }
            let next_focus = (
                PointerFocusTarget::from(&surface),
                (pointer_focus.global_offset.x, pointer_focus.global_offset.y).into(),
            );
            let target_changed =
                data.pointer_focus.as_ref().map(|(target, _)| target) != Some(&next_focus.0);
            data.pointer_focus = Some(next_focus);
            if target_changed {
                data.refresh_pointer_focus();
            }
        }
    } else {
        let had_focus = data.pointer_focus.is_some();
        data.surface_id_under_cursor = None;
        data.pointer_focus = None;
        if had_focus {
            data.refresh_pointer_focus();
        }
    }
    result.success(None);
}
