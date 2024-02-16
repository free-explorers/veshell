use std::time::Duration;

use smithay::backend::input::ButtonState;
use smithay::input::pointer::{ButtonEvent, MotionEvent};
use smithay::reexports::calloop::channel::Event;
use smithay::reexports::calloop::channel::Event::Msg;
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;
use smithay::utils::SERIAL_COUNTER;

use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::mouse_button_tracker::FLUTTER_TO_LINUX_MOUSE_BUTTONS;
use crate::{Backend, CalloopData};

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
            "mouse_button_event" => mouse_button_event(method_call, result, data),
            "activate_window" => activate_window(method_call, result, data),
            "resize_window" => resize_window(method_call, result, data),
            "close_window" => close_window(method_call, result, data),
            "get_monitor_layout" => get_monitor_layout(method_call, result, data),
            _ => result.error(
                "method_not_found".to_string(),
                format!("Method {} not found", method_call.method()),
                None,
            ),
        }
    }
}

macro_rules! extract {
    ($e:expr, $p:path) => {
        match $e {
            $p(value) => value,
            _ => panic!("Failed to extract value"),
        }
    };
}

fn get<'a>(map: &'a EncodableValue, key: &str) -> &'a EncodableValue {
    let map = extract!(map, EncodableValue::Map);
    // TODO: Lookup should be constant time, not linear.
    for (k, v) in map {
        if let EncodableValue::String(k) = k {
            if k == key {
                return v;
            }
        }
    }
    panic!("Key {} not found in map", key);
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

        pointer.motion(
            &mut data.state,
            Some((surface.clone(), (0, 0).into())),
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
struct MouseButtonPayload {
    button: u32,
    is_pressed: bool,
}

pub fn mouse_button_event<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut CalloopData<BackendData>,
) {
    let now = Duration::from(data.state.clock.now()).as_millis() as u32;
    let pointer = data.state.pointer.clone();

    let args = method_call.arguments().unwrap().clone();
    let payload: MouseButtonPayload = serde_json::from_value(args).unwrap();

    pointer.button(
        &mut data.state,
        &ButtonEvent {
            serial: SERIAL_COUNTER.next_serial(),
            time: now,
            button: *FLUTTER_TO_LINUX_MOUSE_BUTTONS.get(&payload.button).unwrap() as u32,
            state: if payload.is_pressed {
                ButtonState::Pressed
            } else {
                ButtonState::Released
            },
        },
    );
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

    if !pointer.is_grabbed() {
        let toplevel = data
            .state
            .xdg_toplevels
            .get(&(payload.surface_id as u64))
            .cloned();
        if let Some(toplevel) = toplevel {
            toplevel.with_pending_state(|state| {
                if payload.activate {
                    state.states.set(xdg_toplevel::State::Activated);
                } else {
                    state.states.unset(xdg_toplevel::State::Activated);
                }
            });
            keyboard.set_focus(&mut data.state, Some(toplevel.wl_surface().clone()), serial);

            for toplevel in data.state.xdg_toplevels.values() {
                toplevel.send_pending_configure();
            }
            result.success(None);
        } else {
            result.error(
                "surface_doesnt_exist".to_string(),
                format!("Surface {} doesn't exist", payload.surface_id),
                None,
            );
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

    match data
        .state
        .xdg_toplevels
        .get(&(payload.surface_id as u64))
        .cloned()
    {
        Some(toplevel) => {
            toplevel.with_pending_state(|state| {
                state.size = Some((payload.width as i32, payload.height as i32).into());
            });
            toplevel.send_pending_configure();
            result.success(None);
        }
        None => result.error(
            "surface_doesnt_exist".to_string(),
            format!("Surface {} doesn't exist", payload.surface_id),
            None,
        ),
    };
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

    match data.state.xdg_toplevels.get(&payload.surface_id).cloned() {
        Some(toplevel) => {
            toplevel.send_close();
            result.success(None);
        }
        None => result.error(
            "surface_doesnt_exist".to_string(),
            format!("Surface {} doesn't exist", payload.surface_id),
            None,
        ),
    };
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
