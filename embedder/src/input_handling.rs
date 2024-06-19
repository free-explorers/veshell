use std::collections::HashSet;
use std::mem::size_of;
use std::sync::atomic::Ordering;

use input_linux::sys::{KEY_ESC, KEY_LEFTALT};
use smithay::backend::input::{
    AbsolutePositionEvent, Axis, AxisRelativeDirection, ButtonState, Event, InputBackend,
    InputEvent, KeyboardKeyEvent, PointerAxisEvent, PointerButtonEvent, PointerMotionEvent,
};
use smithay::input::pointer::AxisFrame;

use crate::flutter_engine::embedder::{
    FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse, FlutterPointerEvent,
    FlutterPointerPhase_kDown, FlutterPointerPhase_kHover, FlutterPointerPhase_kMove,
    FlutterPointerPhase_kUp, FlutterPointerSignalKind_kFlutterPointerSignalKindNone,
    FlutterPointerSignalKind_kFlutterPointerSignalKindScroll,
};
use crate::flutter_engine::FlutterEngine;
use crate::server::ServerState;
use crate::Backend;

pub fn handle_input<BackendData>(
    event: &InputEvent<impl InputBackend>,
    data: &mut ServerState<BackendData>,
) where
    BackendData: Backend + 'static,
{
    match event {
        InputEvent::DeviceAdded { .. } => {}
        InputEvent::DeviceRemoved { .. } => {}
        InputEvent::PointerMotion { event } => {
            clamp_mouse_to_monitor(
                data,
                (
                    data.mouse_position.0 + event.delta_x(),
                    data.mouse_position.1 + event.delta_y(),
                ),
            );
        }
        InputEvent::PointerMotionAbsolute { event } => {
            clamp_mouse_to_monitor(data, (event.x(), event.y()));
        }
        InputEvent::PointerButton { event } => {
            let phase = if event.state() == ButtonState::Pressed {
                let are_any_buttons_pressed = data
                    .flutter_engine()
                    .mouse_button_tracker
                    .are_any_buttons_pressed();
                let _ = data
                    .flutter_engine_mut()
                    .mouse_button_tracker
                    .press(event.button_code() as u16);
                if are_any_buttons_pressed {
                    FlutterPointerPhase_kMove
                } else {
                    FlutterPointerPhase_kDown
                }
            } else {
                let _ = data
                    .flutter_engine_mut()
                    .mouse_button_tracker
                    .release(event.button_code() as u16);
                if data
                    .flutter_engine()
                    .mouse_button_tracker
                    .are_any_buttons_pressed()
                {
                    FlutterPointerPhase_kMove
                } else {
                    FlutterPointerPhase_kUp
                }
            };

            data.flutter_engine()
                .send_pointer_event(FlutterPointerEvent {
                    struct_size: size_of::<FlutterPointerEvent>(),
                    phase,
                    timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
                    x: data.mouse_position.0,
                    y: data.mouse_position.1,
                    device: 0,
                    signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindNone,
                    scroll_delta_x: 0.0,
                    scroll_delta_y: 0.0,
                    device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
                    buttons: data
                        .flutter_engine()
                        .mouse_button_tracker
                        .get_flutter_button_bitmask(),
                    pan_x: 0.0,
                    pan_y: 0.0,
                    scale: 1.0,
                    rotation: 0.0,
                })
                .unwrap();
        }
        InputEvent::PointerAxis { event } => {
            let horizontal_discrete = event.amount_v120(Axis::Horizontal);
            let vertical_discrete = event.amount_v120(Axis::Vertical);

            let horizontal = event
                .amount(Axis::Horizontal)
                // Fall back on discrete scroll if continuous scroll is not available.
                .or(horizontal_discrete)
                .unwrap_or(0.0);
            let vertical = event
                .amount(Axis::Vertical)
                .or(vertical_discrete)
                .unwrap_or(0.0);

            let pointer = data.pointer.clone();
            pointer.axis(
                data,
                AxisFrame {
                    source: Some(event.source()),
                    relative_direction: (
                        AxisRelativeDirection::Identical,
                        AxisRelativeDirection::Identical,
                    ),
                    time: (event.time() / 1000) as u32, // us to ms
                    axis: (horizontal, vertical),
                    v120: if let (None, None) = (horizontal_discrete, vertical_discrete) {
                        None
                    } else {
                        Some((
                            horizontal_discrete.unwrap_or(0.0) as i32,
                            vertical_discrete.unwrap_or(0.0) as i32,
                        ))
                    },
                    stop: (false, false),
                },
            );
            pointer.frame(data);

            data.flutter_engine()
                .send_pointer_event(FlutterPointerEvent {
                    struct_size: size_of::<FlutterPointerEvent>(),
                    phase: if data
                        .flutter_engine()
                        .mouse_button_tracker
                        .are_any_buttons_pressed()
                    {
                        FlutterPointerPhase_kMove
                    } else {
                        FlutterPointerPhase_kDown
                    },
                    timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
                    x: data.mouse_position.0,
                    y: data.mouse_position.1,
                    device: 0,
                    signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindScroll,
                    scroll_delta_x: horizontal,
                    scroll_delta_y: vertical,
                    device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
                    buttons: data
                        .flutter_engine()
                        .mouse_button_tracker
                        .get_flutter_button_bitmask(),
                    pan_x: 0.0,
                    pan_y: 0.0,
                    scale: 1.0,
                    rotation: 0.0,
                })
                .unwrap();
        }
        InputEvent::Keyboard { event } => {
            data.handle_key_event(event.key_code(), event.state(), event.time_msec());

            let pressed_keys = data
                .keyboard
                .pressed_keys()
                .iter()
                .map(|key| key.raw())
                .collect::<HashSet<_>>();

            if pressed_keys.contains(&(KEY_ESC as u32))
                && pressed_keys.contains(&(KEY_LEFTALT as u32))
            {
                data.running.store(false, Ordering::SeqCst);
                return;
            }
        }
        InputEvent::GestureSwipeBegin { .. } => {}
        InputEvent::GestureSwipeUpdate { .. } => {}
        InputEvent::GestureSwipeEnd { .. } => {}
        InputEvent::GesturePinchBegin { .. } => {}
        InputEvent::GesturePinchUpdate { .. } => {}
        InputEvent::GesturePinchEnd { .. } => {}
        InputEvent::GestureHoldBegin { .. } => {}
        InputEvent::GestureHoldEnd { .. } => {}
        InputEvent::TouchDown { .. } => {}
        InputEvent::TouchMotion { .. } => {}
        InputEvent::TouchUp { .. } => {}
        InputEvent::TouchCancel { .. } => {}
        InputEvent::TouchFrame { .. } => {}
        InputEvent::TabletToolAxis { .. } => {}
        InputEvent::TabletToolProximity { .. } => {}
        InputEvent::TabletToolTip { .. } => {}
        InputEvent::TabletToolButton { .. } => {}
        InputEvent::Special(_) => {}
        InputEvent::SwitchToggle { .. } => {}
    }
}

fn clamp_mouse_to_monitor<BackendData>(
    data: &mut ServerState<BackendData>,
    new_mouse_position: (f64, f64),
) where
    BackendData: Backend + 'static,
{
    let outputs: Vec<smithay::output::Output> = data.backend_data.get_monitor_layout();

    let mut clamped_position = new_mouse_position;

    for output in outputs {
        let location = output.current_location();
        let size = output.current_mode().unwrap().size;

        // Clamp x-coordinate
        if clamped_position.0 < location.x as f64 {
            clamped_position.0 = location.x as f64;
        } else if clamped_position.0 > (location.x as f64 + size.w as f64) {
            clamped_position.0 = location.x as f64 + size.w as f64;
        }

        // Clamp y-coordinate
        if clamped_position.1 < location.y as f64 {
            clamped_position.1 = location.y as f64;
        } else if clamped_position.1 > (location.y as f64 + size.h as f64) {
            clamped_position.1 = location.y as f64 + size.h as f64;
        }
    }

    data.mouse_position = clamped_position;
    send_motion_event(data);
}

fn send_motion_event<BackendData>(data: &mut ServerState<BackendData>)
where
    BackendData: Backend + 'static,
{
    data.flutter_engine()
        .send_pointer_event(FlutterPointerEvent {
            struct_size: size_of::<FlutterPointerEvent>(),
            phase: if data
                .flutter_engine()
                .mouse_button_tracker
                .are_any_buttons_pressed()
            {
                FlutterPointerPhase_kMove
            } else {
                FlutterPointerPhase_kHover
            },
            timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
            x: data.mouse_position.0,
            y: data.mouse_position.1,
            device: 0,
            signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindNone,
            scroll_delta_x: 0.0,
            scroll_delta_y: 0.0,
            device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
            buttons: data
                .flutter_engine()
                .mouse_button_tracker
                .get_flutter_button_bitmask(),
            pan_x: 0.0,
            pan_y: 0.0,
            scale: 1.0,
            rotation: 0.0,
        })
        .unwrap();
}
