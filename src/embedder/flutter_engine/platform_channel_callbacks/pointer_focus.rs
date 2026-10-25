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
            // A floating X11 window's native position is authoritative. The
            // Flutter render box can lag or clamp while the client moves itself
            // (Zoom's panels), and feeding that back into the pointer basis is
            // what makes the client's own drag accelerate.
            let flutter_offset = (pointer_focus.global_offset.x, pointer_focus.global_offset.y);
            let mut global_offset = flutter_offset.into();
            if let Some(meta_window_id) = data
                .meta_window_state
                .meta_window_id_per_surface_id
                .get(&pointer_focus.surface_id)
            {
                if let Some(meta_window) = data.meta_window_state.meta_windows.get(meta_window_id) {
                    if meta_window.is_floating() {
                        if let Some(native) = meta_window.surface_origin() {
                            global_offset = native;
                            if (native.x - flutter_offset.0).abs() > 1.0
                                || (native.y - flutter_offset.1).abs() > 1.0
                            {
                                tracing::debug!(
                                    target: "veshell::geometry",
                                    surface_id = pointer_focus.surface_id,
                                    native = ?(native.x, native.y),
                                    flutter = ?flutter_offset,
                                    "using native floating pointer basis"
                                );
                            }
                        }
                    }
                }
            }
            // A popup can move itself under the cursor (override-redirect
            // menus/toolbars). Flutter's render origin lags the configure
            // event, so derive the basis from the native position plus the
            // render offset seen while the popup was stationary. Otherwise the
            // client's local pointer feeds its own movement back into it.
            if let Some(popup_id) = data
                .meta_window_state
                .meta_popup_id_per_surface_id
                .get(&pointer_focus.surface_id)
            {
                if let Some(popup) = data.meta_window_state.meta_popups.get(popup_id) {
                    let geometry = popup
                        .geometry
                        .as_ref()
                        .map(|geometry| (f64::from(geometry.0.loc.x), f64::from(geometry.0.loc.y)))
                        .unwrap_or((0.0, 0.0));
                    let parent_box = data.meta_window_state.meta_window_box_origin(&popup.parent);
                    let native = smithay::utils::Point::from((
                        f64::from(parent_box.x + popup.position.0.x) - geometry.0,
                        f64::from(parent_box.y + popup.position.0.y) - geometry.1,
                    ));
                    let flutter = smithay::utils::Point::from((flutter_offset.0, flutter_offset.1));
                    let previous_native = data
                        .popup_last_native
                        .get(&pointer_focus.surface_id)
                        .copied();
                    let mut offset = data
                        .popup_render_offsets
                        .get(&pointer_focus.surface_id)
                        .copied()
                        .unwrap_or(flutter - native);
                    if previous_native == Some(popup.position.0) {
                        // The popup did not move since the previous focus
                        // request: Flutter's origin is current, so refresh the
                        // tile/parent offset.
                        offset = flutter - native;
                    }
                    data.popup_render_offsets
                        .insert(pointer_focus.surface_id, offset);
                    data.popup_last_native
                        .insert(pointer_focus.surface_id, popup.position.0);
                    global_offset = native + offset;
                }
            }
            let next_focus = (PointerFocusTarget::from(&surface), global_offset);
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
