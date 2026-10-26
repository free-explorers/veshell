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
        // An explicit popup grab owns the pointer until release. Flutter
        // hover can report the parent when the popup moves under the cursor,
        // but switching focus there feeds the popup's own configure delta
        // back into the client as a different local pointer basis.
        if let Some(grab) = data.popup_pointer_grab {
            if !data
                .flutter_engine()
                .mouse_button_tracker
                .are_any_buttons_pressed()
            {
                // Missed release: do not leave the popup grab latched.
                data.popup_pointer_grab = None;
            } else if grab.surface_id != pointer_focus.surface_id {
                result.success(None);
                return;
            }
        }
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
            // menus/toolbars). Derive its surface origin from the parent render
            // origin published by Flutter, so a native move is reflected before
            // Flutter has laid out the new popup position.
            if let Some(popup_id) = data
                .meta_window_state
                .meta_popup_id_per_surface_id
                .get(&pointer_focus.surface_id)
            {
                if let Some(popup) = data.meta_window_state.meta_popups.get(popup_id) {
                    // During an override-redirect drag the client moves itself
                    // from the configure stream. Keep the basis the configure
                    // delta already advanced instead of replacing it with a
                    // Flutter origin sampled before the last layout. The model
                    // origin is used outside the explicit grab.
                    let grab_active = data
                        .popup_pointer_grab
                        .is_some_and(|grab| grab.surface_id == pointer_focus.surface_id);
                    if grab_active {
                        // Keep the basis the configure stream has already
                        // advanced by its delta. A Flutter origin sampled
                        // before the last layout can lag the popup.
                        if let Some((target, offset)) = data.pointer_focus.as_ref() {
                            if *target == PointerFocusTarget::from(&surface) {
                                global_offset = *offset;
                            }
                        }
                    } else if let Some(origin) = data.meta_window_state.popup_surface_origin(popup)
                    {
                        global_offset = origin;
                    }
                    let parent = data.meta_window_state.meta_windows.get(&popup.parent);
                    tracing::debug!(
                        target: "veshell::popup_drag",
                        surface_id = pointer_focus.surface_id,
                        flutter_offset = ?(flutter_offset.0, flutter_offset.1),
                        popup_position = ?popup.position.0,
                        popup_geometry = ?popup.geometry.as_ref().map(|g| g.0.loc),
                        parent_id = %popup.parent,
                        parent_position = ?parent.and_then(|w| w.position.as_ref().map(|p| p.0)),
                        parent_render_origin = ?parent.and_then(|w| w.render_origin.as_ref().map(|p| p.0)),
                        parent_surface_origin = ?parent.and_then(|w| w.surface_origin()),
                        parent_floating = ?parent.map(|w| w.is_floating()),
                        model_origin = ?data.meta_window_state.popup_surface_origin(popup),
                        chosen = ?(global_offset.x, global_offset.y),
                        pointer = ?data.pointer.current_location(),
                        buttons = data.flutter_engine().mouse_button_tracker.are_any_buttons_pressed(),
                        grab_owner = ?data.popup_pointer_grab.map(|grab| grab.surface_id),
                        "popup_drag_focus"
                    );
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
