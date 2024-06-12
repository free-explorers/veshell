use std::borrow::Borrow;
use std::cell::RefCell;
use std::collections::HashMap;
use std::time::Duration;

use serde_json::json;
use smithay::backend::input::ButtonState;
use smithay::backend::x11;
use smithay::input::pointer::{ButtonEvent, MotionEvent};
use smithay::reexports::calloop::channel::Event;
use smithay::reexports::calloop::channel::Event::Msg;
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;
use smithay::utils::SERIAL_COUNTER;
use smithay::wayland::compositor::with_states;
use smithay::wayland::shell::xdg;
use smithay::wayland::xwayland_shell::XWAYLAND_SHELL_ROLE;
use smithay::xwayland::xwm;

use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::flutter_engine::wayland_messages::NewX11Surface;
use crate::focus::{KeyboardFocusTarget, PointerFocusTarget};
use crate::mouse_button_tracker::FLUTTER_TO_LINUX_MOUSE_BUTTONS;

use crate::server::{get_surface_id, ServerState};
use crate::Backend;

pub fn platform_channel_method_handler<BackendData: Backend + 'static>(
    event: Event<(
        MethodCall<serde_json::Value>,
        Box<dyn MethodResult<serde_json::Value>>,
    )>,
    _: &mut (),
    data: &mut ServerState<BackendData>,
) {
    if let Msg((method_call, mut result)) = event {
        match method_call.method() {
            "pointer_hover" => pointer_hover(method_call, result, data),
            "pointer_exit" => pointer_exit(method_call, result, data),
            "mouse_buttons_event" => mouse_buttons_event(method_call, result, data),
            "activate_window" => activate_window(method_call, result, data),
            "resize_window" => resize_window(method_call, result, data),
            "close_window" => close_window(method_call, result, data),
            "get_monitor_layout" => get_monitor_layout(method_call, result, data),
            "get_environment_variables" => get_environment_variables(method_call, result, data),
            "shell_ready" => on_shell_ready(method_call, result, data),
            _ => result.error(
                "method_not_found".to_string(),
                format!("Method {} not found", method_call.method()),
                None,
            ),
        }
    }
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct PointerHoverPayload {
    surface_id: u64,
    x: f64,
    y: f64,
}

pub fn pointer_hover<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut ServerState<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: PointerHoverPayload = serde_json::from_value(args).unwrap();

    data.surface_id_under_cursor = Some(payload.surface_id);

    if let Some(surface) = data.surfaces.get(&payload.surface_id).cloned() {
        let now = Duration::from(data.clock.now()).as_millis() as u32;
        let pointer = data.pointer.clone();

        if let Some(x11_surface) = data.x11_surface_per_wl_surface.get(&surface).cloned() {
            let _ = data.x11_wm.as_mut().unwrap().raise_window(&x11_surface);
        }

        pointer.motion(
            data,
            Some((PointerFocusTarget::from(surface), (0, 0).into())),
            &MotionEvent {
                location: (payload.x, payload.y).into(),
                serial: SERIAL_COUNTER.next_serial(),
                time: now,
            },
        );
        pointer.frame(data);
        result.success(None);
    } else {
        result.error(
            "surface_doesnt_exist".to_string(),
            format!("Surface {} doesn't exist", payload.surface_id),
            None,
        );
    }
}

pub fn pointer_exit<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut ServerState<BackendData>,
) {
    let now = Duration::from(data.clock.now()).as_millis() as u32;
    let pointer = data.pointer.clone();

    data.surface_id_under_cursor = None;

    pointer.motion(
        data,
        None,
        &MotionEvent {
            location: (0.0, 0.0).into(),
            serial: SERIAL_COUNTER.next_serial(),
            time: now,
        },
    );
    result.success(None);
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct MouseButtonsPayload {
    surface_id: u64,
    buttons: Vec<Button>,
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct Button {
    button: u32,
    is_pressed: bool,
}

pub fn mouse_buttons_event<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut ServerState<BackendData>,
) {
    let now = Duration::from(data.clock.now()).as_millis() as u32;
    let pointer = data.pointer.clone();

    let args = method_call.arguments().unwrap().clone();
    let payload: MouseButtonsPayload = serde_json::from_value(args).unwrap();

    for button in payload.buttons {
        pointer.button(
            data,
            &ButtonEvent {
                serial: SERIAL_COUNTER.next_serial(),
                time: now,
                button: *FLUTTER_TO_LINUX_MOUSE_BUTTONS.get(&button.button).unwrap() as u32,
                state: if button.is_pressed {
                    ButtonState::Pressed
                } else {
                    ButtonState::Released
                },
            },
        );
    }

    pointer.frame(data);
    result.success(None);
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct ActivateWindowPayload {
    surface_id: u64,
    activate: bool,
}

pub fn activate_window<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut ServerState<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: ActivateWindowPayload = serde_json::from_value(args).unwrap();

    let pointer = data.seat.get_pointer().unwrap();
    let keyboard = data.seat.get_keyboard().unwrap();

    let serial = SERIAL_COUNTER.next_serial();

    if pointer.is_grabbed() {
        result.success(None);
        return;
    }

    let Some(wl_surface) = data.surfaces.get(&payload.surface_id).cloned() else {
        result.error(
            "surface_doesnt_exist".to_string(),
            format!("Surface {} doesn't exist", payload.surface_id),
            None,
        );
        return;
    };

    let role = with_states(&wl_surface, |states| states.role);
    match role {
        Some(xdg::XDG_TOPLEVEL_ROLE) => {
            let toplevel = data.xdg_toplevels.get(&payload.surface_id).cloned();

            let Some(toplevel) = toplevel else {
                result.error(
                    "toplevel_doesnt_exist".to_string(),
                    format!("Toplevel {} doesn't exist", payload.surface_id),
                    None,
                );
                return;
            };

            toplevel.with_pending_state(|state| {
                if payload.activate {
                    state.states.set(xdg_toplevel::State::Activated);
                } else {
                    state.states.unset(xdg_toplevel::State::Activated);
                }
            });
            toplevel.send_pending_configure();

            if payload.activate {
                keyboard.set_focus(
                    data,
                    Some(KeyboardFocusTarget::WlSurface(wl_surface)),
                    serial,
                );
            }

            result.success(None);
        }
        Some(XWAYLAND_SHELL_ROLE) => {
            let Some(x11_surface) = data.x11_surface_per_wl_surface.get(&wl_surface).cloned()
            else {
                result.error(
                    "x11_surface_doesnt_exist".to_string(),
                    format!("X11 Surface {} doesn't exist", payload.surface_id),
                    None,
                );
                return;
            };
            x11_surface.set_activated(payload.activate).unwrap();

            if payload.activate && !x11_surface.is_override_redirect() {
                let _ = data.x11_wm.as_mut().unwrap().raise_window(&x11_surface);

                keyboard.set_focus(
                    data,
                    Some(KeyboardFocusTarget::X11Surface(x11_surface)),
                    serial,
                );
            }

            result.success(None);
        }
        _ => {
            result.error(
                "invalid_surface_role".to_string(),
                format!("Surface {} has an invalid role", payload.surface_id),
                None,
            );
            return;
        }
    }
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct ResizeWindowPayload {
    surface_id: u64,
    width: i32,
    height: i32,
}

pub fn resize_window<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut ServerState<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: ResizeWindowPayload = serde_json::from_value(args).unwrap();

    let Some(wl_surface) = data.surfaces.get(&payload.surface_id).cloned() else {
        result.error(
            "surface_doesnt_exist".to_string(),
            format!("Surface {} doesn't exist", payload.surface_id),
            None,
        );
        return;
    };

    let role = with_states(&wl_surface, |states| states.role);
    match role {
        Some(xdg::XDG_TOPLEVEL_ROLE) => {
            let toplevel = data.xdg_toplevels.get(&payload.surface_id).cloned();

            let Some(toplevel) = toplevel else {
                result.error(
                    "toplevel_doesnt_exist".to_string(),
                    format!("Toplevel {} doesn't exist", payload.surface_id),
                    None,
                );
                return;
            };

            toplevel.with_pending_state(|state| {
                state.size = Some((payload.width, payload.height).into());
            });
            toplevel.send_pending_configure();

            result.success(None);
        }
        Some(XWAYLAND_SHELL_ROLE) => {
            let Some(x11_surface) = data.x11_surface_per_wl_surface.get(&wl_surface) else {
                result.error(
                    "x11_surface_doesnt_exist".to_string(),
                    format!("X11 Surface {} doesn't exist", payload.surface_id),
                    None,
                );
                return;
            };

            if x11_surface.is_override_redirect() {
                result.error(
                    "resize_unsupported_for_override_redirect_x11_surfaces".to_string(),
                    format!(
                        "Resize unsupported for override redirect X11 surface {}",
                        payload.surface_id,
                    ),
                    None,
                );
                return;
            }

            let mut geometry = x11_surface.geometry();
            geometry.size = (payload.width, payload.height).into();
            x11_surface.configure(geometry).unwrap();

            result.success(None);
        }
        _ => {
            result.error(
                "invalid_surface_role".to_string(),
                format!("Surface {} has an invalid role", payload.surface_id),
                None,
            );
            return;
        }
    }
}

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
struct CloseWindowPayload {
    surface_id: u64,
}

pub fn close_window<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut ServerState<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: CloseWindowPayload = serde_json::from_value(args).unwrap();

    let Some(wl_surface) = data.surfaces.get(&payload.surface_id).cloned() else {
        result.error(
            "surface_doesnt_exist".to_string(),
            format!("Surface {} doesn't exist", payload.surface_id),
            None,
        );
        return;
    };

    let role = with_states(&wl_surface, |states| states.role);
    match role {
        Some(xdg::XDG_TOPLEVEL_ROLE) => {
            let toplevel = data.xdg_toplevels.get(&payload.surface_id).cloned();

            let Some(toplevel) = toplevel else {
                result.error(
                    "toplevel_doesnt_exist".to_string(),
                    format!("Toplevel {} doesn't exist", payload.surface_id),
                    None,
                );
                return;
            };

            toplevel.send_close();
            result.success(None);
        }
        Some(XWAYLAND_SHELL_ROLE) => {
            let Some(x11_surface) = data.x11_surface_per_wl_surface.get(&wl_surface) else {
                result.error(
                    "x11_surface_doesnt_exist".to_string(),
                    format!("X11 Surface {} doesn't exist", payload.surface_id),
                    None,
                );
                return;
            };

            let _ = x11_surface.close();
            result.success(None);
        }
        _ => {
            result.error(
                "invalid_surface_role".to_string(),
                format!("Surface {} has an invalid role", payload.surface_id),
                None,
            );
            return;
        }
    }
}

pub fn get_monitor_layout<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut ServerState<BackendData>,
) {
    let monitors = data.backend_data.get_monitor_layout();
    data.flutter_engine_mut().monitor_layout_changed(monitors);
    result.success(None);
}

pub fn get_environment_variables<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut ServerState<BackendData>,
) {
    let wayland_socket_name = data.wayland_socket_name.as_deref();

    let xwayland_display = data.xwayland_display.map(|display| format!(":{}", display));
    let xwayland_display = xwayland_display.as_deref();

    data.flutter_engine
        .as_mut()
        .unwrap()
        .set_environment_variables(HashMap::from([
            ("WAYLAND_DISPLAY", wayland_socket_name),
            ("DISPLAY", xwayland_display),
        ]));

    result.success(None);
}

// For development purpose the shell can reload to apply current changes
// In order to be the most transparent for the dev
// We resend all existing surfaces to it so it can benefit from the Persistence
pub fn on_shell_ready<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut ServerState<BackendData>,
) {
    let surfaces = data.surfaces.clone();

    println!("on_shell_ready");
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

    let toplevels = data.xdg_toplevels.clone();
    for surface_id in toplevels.keys() {
        let platform_method_channel = &mut data.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "new_toplevel",
            Some(Box::new(json!({
                "surfaceId": surface_id,
            }))),
            None,
        );
    }

    let popups = data.xdg_popups.clone();
    for surface_id in popups.keys() {
        if let Some(wl_surface) = surfaces.get(surface_id) {
            let (parent, position) = {
                let popup_message = data.construct_popup_role_message(wl_surface.clone().borrow());
                (
                    popup_message.as_ref().unwrap().parent,
                    popup_message.unwrap().position,
                )
            };
            let platform_method_channel = &mut data.flutter_engine_mut().platform_method_channel;
            platform_method_channel.invoke_method(
                "new_popup",
                Some(Box::new(json!({
                    "surfaceId": surface_id,
                    "parent": parent,
                    "position": position,
                }))),
                None,
            );
        }
    }
    let subsurfaces = data.subsurfaces.clone();

    for surface_id in subsurfaces.keys() {
        if let Some(wl_surface) = surfaces.get(surface_id) {
            let subsurface_message = ServerState::<BackendData>::construct_subsurface_role_message(
                wl_surface.clone().borrow(),
            );
            let platform_method_channel: &mut crate::flutter_engine::platform_channels::method_channel::MethodChannel<serde_json::Value> = &mut data.flutter_engine_mut().platform_method_channel;

            platform_method_channel.invoke_method(
                "new_subsurface",
                Some(Box::new(json!({
                    "surfaceId": surface_id,
                    "parentId": subsurface_message.parent,
                }))),
                None,
            );
        }
    }

    let x11_surfaces = data.x11_surface_per_x11_window.clone();

    for x11_surface in x11_surfaces.values() {
        let platform_method_channel = &mut data.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "new_x11_surface",
            Some(Box::new(json!(NewX11Surface {
                x11_surface_id: ServerState::<BackendData>::get_x11_surface_id(&x11_surface),
                override_redirect: x11_surface.is_override_redirect(),
            }))),
            None,
        );
    }

    for x11_surface in x11_surfaces.values() {
        let platform_method_channel = &mut data.flutter_engine_mut().platform_method_channel;

        platform_method_channel.invoke_method(
            "x11_properties_changed",
            Some(Box::new(json!({
                "x11SurfaceId": ServerState::<BackendData>::get_x11_surface_id(&x11_surface),
                "title": if !x11_surface.title().is_empty() { Some(x11_surface.title()) } else { None },
                "windowClass": x11_surface.class(),
                "instance": if !x11_surface.instance().is_empty() {
                    Some(x11_surface.instance())
                } else {
                    None
                },
                "startupId": x11_surface.startup_id(),
            }))),
            None,
        );
        if (x11_surface.is_mapped()) {
            platform_method_channel.invoke_method(
                "surface_associated",
                Some(Box::new(json!({
                    "surfaceId":  get_surface_id(x11_surface.wl_surface().unwrap().borrow()),
                    "x11SurfaceId": ServerState::<BackendData>::get_x11_surface_id(&x11_surface),
                }))),
                None,
            );
            data.map_x11_surface(x11_surface.clone());
        }
    }

    // send commited_state for all existing surface
    for surface_id in surfaces.keys() {
        if let Some(wl_surface) = surfaces.get(surface_id) {
            let surface_message = data.construct_surface_message(wl_surface.clone().borrow());
            let platform_method_channel = &mut data.flutter_engine_mut().platform_method_channel;
            platform_method_channel.invoke_method(
                "commit_surface",
                Some(Box::new(json!(surface_message))),
                None,
            );
        }
    }
    result.success(None);
}
