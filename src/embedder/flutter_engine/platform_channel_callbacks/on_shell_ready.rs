use std::borrow::Borrow;

use crate::flutter_engine::platform_channels::method_result::MethodResult;

use crate::flutter_engine::platform_channels::method_call::MethodCall;

use crate::backend::Backend;
use crate::flutter_engine::wayland_messages::NewX11Surface;
use crate::wayland::wayland::get_surface_id;
use serde_json::json;
use smithay::reexports::wayland_server::Resource;

use crate::state::State;

// For development purpose the shell can reload to apply current changes
// In order to be the most transparent for the dev
// We resend all existing surfaces to it so it can benefit from the Persistence
pub fn on_shell_ready<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let surfaces = data.surfaces.clone();

    tracing::info!("on_shell_ready");
    // Send new_surface for all existing surface
    for surface_id in surfaces.keys() {
        let platform_method_channel = &mut data.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "new_surface",
            Some(Box::new(json!({
                "surfaceId": surface_id,
            }))),
            None,
        );
    }
    let subsurfaces = data.subsurfaces.clone();

    for surface_id in subsurfaces.keys() {
        if let Some(wl_surface) = surfaces.get(surface_id) {
            let subsurface_message = State::<BackendData>::construct_subsurface_role_message(
                wl_surface.clone().borrow(),
            );
            let platform_method_channel: &mut crate::flutter_engine::platform_channels::method_channel::MethodChannel<serde_json::Value> = &mut data.flutter_engine_mut().platform_method_channel;

            platform_method_channel.invoke_method(
                "new_subsurface",
                Some(Box::new(json!({
                    "surfaceId": surface_id,
                    "parent": subsurface_message.parent,
                }))),
                None,
            );
        }
    }

    // send commited_state for all existing surface
    for surface_id in surfaces.keys() {
        if let Some(wl_surface) = surfaces.get(surface_id) {
            let surface_message = data.construct_surface_message(wl_surface.clone().borrow());
            let platform_method_channel = &mut data.flutter_engine_mut().platform_method_channel;
            tracing::info!("Restore commit_surface");
            platform_method_channel.invoke_method(
                "commit_surface",
                Some(Box::new(json!(surface_message))),
                None,
            );
        }
    }

    // send new meta_window for all existing meta_window

    result.success(None);
}
