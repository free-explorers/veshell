use std::collections::HashMap;
use std::time::Duration;

use smithay::backend::input::ButtonState;
use smithay::input::pointer::{ButtonEvent, MotionEvent};
use smithay::reexports::calloop::channel::Event;
use smithay::reexports::calloop::channel::Event::Msg;
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;
use smithay::utils::SERIAL_COUNTER;
use smithay::wayland::compositor::with_states;
use smithay::wayland::shell::xdg;
use smithay::xwayland::xwm;

use crate::{Backend, CalloopData};
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::focus::{KeyboardFocusTarget, PointerFocusTarget};
use crate::mouse_button_tracker::FLUTTER_TO_LINUX_MOUSE_BUTTONS;

pub fn platform_channel_method_handler<BackendData: Backend + 'static>(
    event: Event<(
        MethodCall<serde_json::Value>,
        Box<dyn MethodResult<serde_json::Value>>,
    )>,
    _: &mut (),
    data: &mut CalloopData<BackendData>,
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
    data: &mut CalloopData<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: PointerHoverPayload = serde_json::from_value(args).unwrap();

    data.state.surface_id_under_cursor = Some(payload.surface_id);

    if let Some(surface) = data.state.surfaces.get(&payload.surface_id).cloned() {
        let now = Duration::from(data.state.clock.now()).as_millis() as u32;
        let pointer = data.state.pointer.clone();

        if let Some(x11_surface) = data.state.x11_surface_per_wl_surface.get(&surface).cloned() {
            let _ = data
                .state
                .x11_wm
                .as_mut()
                .unwrap()
                .raise_window(&x11_surface);
        }

        pointer.motion(
            &mut data.state,
            Some((PointerFocusTarget::from(surface), (0, 0).into())),
            &MotionEvent {
                location: (payload.x, payload.y).into(),
                serial: SERIAL_COUNTER.next_serial(),
                time: now,
            },
        );
        pointer.frame(&mut data.state);
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
    data: &mut CalloopData<BackendData>,
) {
    let now = Duration::from(data.state.clock.now()).as_millis() as u32;
    let pointer = data.state.pointer.clone();

    data.state.surface_id_under_cursor = None;

    pointer.motion(
        &mut data.state,
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
    data: &mut CalloopData<BackendData>,
) {
    let now = Duration::from(data.state.clock.now()).as_millis() as u32;
    let pointer = data.state.pointer.clone();

    let args = method_call.arguments().unwrap().clone();
    let payload: MouseButtonsPayload = serde_json::from_value(args).unwrap();

    for button in payload.buttons {
        pointer.button(
            &mut data.state,
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

    pointer.frame(&mut data.state);
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
    data: &mut CalloopData<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: ActivateWindowPayload = serde_json::from_value(args).unwrap();

    let pointer = data.state.seat.get_pointer().unwrap();
    let keyboard = data.state.seat.get_keyboard().unwrap();

    let serial = SERIAL_COUNTER.next_serial();

    if pointer.is_grabbed() {
        result.success(None);
        return;
    }

    let Some(wl_surface) = data.state.surfaces.get(&payload.surface_id).cloned() else {
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
            let toplevel = data.state.xdg_toplevels.get(&payload.surface_id).cloned();

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
                    &mut data.state,
                    Some(KeyboardFocusTarget::WlSurface(wl_surface)),
                    serial,
                );
            }

            result.success(None);
        }
        Some(xwm::X11_SURFACE_ROLE) => {
            let Some(x11_surface) = data
                .state
                .x11_surface_per_wl_surface
                .get(&wl_surface)
                .cloned()
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
                let _ = data
                    .state
                    .x11_wm
                    .as_mut()
                    .unwrap()
                    .raise_window(&x11_surface);

                keyboard.set_focus(
                    &mut data.state,
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
    data: &mut CalloopData<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: ResizeWindowPayload = serde_json::from_value(args).unwrap();

    let Some(wl_surface) = data.state.surfaces.get(&payload.surface_id).cloned() else {
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
            let toplevel = data.state.xdg_toplevels.get(&payload.surface_id).cloned();

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
        Some(xwm::X11_SURFACE_ROLE) => {
            let Some(x11_surface) = data.state.x11_surface_per_wl_surface.get(&wl_surface) else {
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
    data: &mut CalloopData<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: CloseWindowPayload = serde_json::from_value(args).unwrap();

    let Some(wl_surface) = data.state.surfaces.get(&payload.surface_id).cloned() else {
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
            let toplevel = data.state.xdg_toplevels.get(&payload.surface_id).cloned();

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
        Some(xwm::X11_SURFACE_ROLE) => {
            let Some(x11_surface) = data.state.x11_surface_per_wl_surface.get(&wl_surface) else {
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
    data: &mut CalloopData<BackendData>,
) {
    let monitors = data.state.backend_data.get_monitor_layout();
    data.state
        .flutter_engine_mut()
        .monitor_layout_changed(monitors);
    result.success(None);
}

pub fn get_environment_variables<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut CalloopData<BackendData>,
) {
    let wayland_socket_name = data.state.wayland_socket_name.as_deref();

    let xwayland_display = data
        .state
        .xwayland_display
        .map(|display| format!(":{}", display));
    let xwayland_display = xwayland_display.as_deref();

    data.state
        .flutter_engine
        .as_mut()
        .unwrap()
        .set_environment_variables(HashMap::from([
            ("WAYLAND_DISPLAY", wayland_socket_name),
            ("DISPLAY", xwayland_display),
        ]));

    result.success(None);
}
