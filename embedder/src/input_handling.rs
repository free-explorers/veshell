use std::mem::size_of;
use std::sync::atomic::Ordering;
use std::time::Duration;

use input_linux::sys::KEY_ESC;
use smithay::backend::input::{AbsolutePositionEvent, Axis, AxisRelativeDirection, ButtonState, Event, InputBackend, InputEvent, KeyboardKeyEvent, KeyState, PointerAxisEvent, PointerButtonEvent, PointerMotionEvent};
use smithay::input::pointer::AxisFrame;

use crate::{Backend, CalloopData};
use crate::flutter_engine::embedder::{FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse, FlutterPointerEvent, FlutterPointerPhase_kDown, FlutterPointerPhase_kHover, FlutterPointerPhase_kMove, FlutterPointerPhase_kUp, FlutterPointerSignalKind_kFlutterPointerSignalKindNone, FlutterPointerSignalKind_kFlutterPointerSignalKindScroll};
use crate::flutter_engine::FlutterEngine;
use crate::keyboard::KeyEvent;

pub fn handle_input<BackendData>(event: &InputEvent<impl InputBackend>, data: &mut CalloopData<BackendData>)
    where BackendData: Backend + 'static
{
    match event {
        InputEvent::DeviceAdded { .. } => {}
        InputEvent::DeviceRemoved { .. } => {}
        InputEvent::PointerMotion { event } => {
            data.state.mouse_position.0 += event.delta_x();
            data.state.mouse_position.1 += event.delta_y();
            send_motion_event(data);
        }
        InputEvent::PointerMotionAbsolute { event } => {
            data.state.mouse_position = (event.x(), event.y());
            send_motion_event(data);
        }
        InputEvent::PointerButton { event } => {
            let phase = if event.state() == ButtonState::Pressed {
                let are_any_buttons_pressed = data.state.flutter_engine().mouse_button_tracker.are_any_buttons_pressed();
                let _ = data.state.flutter_engine_mut().mouse_button_tracker.press(event.button_code() as u16);
                if are_any_buttons_pressed {
                    FlutterPointerPhase_kMove
                } else {
                    FlutterPointerPhase_kDown
                }
            } else {
                let _ = data.state.flutter_engine_mut().mouse_button_tracker.release(event.button_code() as u16);
                if data.state.flutter_engine().mouse_button_tracker.are_any_buttons_pressed() {
                    FlutterPointerPhase_kMove
                } else {
                    FlutterPointerPhase_kUp
                }
            };

            data.state.flutter_engine().send_pointer_event(FlutterPointerEvent {
                struct_size: size_of::<FlutterPointerEvent>(),
                phase,
                timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
                x: data.state.mouse_position.0,
                y: data.state.mouse_position.1,
                device: 0,
                signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindNone,
                scroll_delta_x: 0.0,
                scroll_delta_y: 0.0,
                device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
                buttons: data.state.flutter_engine().mouse_button_tracker.get_flutter_button_bitmask(),
                pan_x: 0.0,
                pan_y: 0.0,
                scale: 0.0,
                rotation: 0.0,
            }).unwrap();
        }
        InputEvent::PointerAxis { event } => {
            let horizontal_discrete = event.amount_v120(Axis::Horizontal);
            let vertical_discrete = event.amount_v120(Axis::Vertical);

            let horizontal = event.amount(Axis::Horizontal)
                // Fall back on discrete scroll if continuous scroll is not available.
                .or(horizontal_discrete).unwrap_or(0.0);
            let vertical = event.amount(Axis::Vertical)
                .or(vertical_discrete).unwrap_or(0.0);

            let pointer = data.state.pointer.clone();
            pointer.axis(
                &mut data.state,
                AxisFrame {
                    source: Some(event.source()),
                    relative_direction: (AxisRelativeDirection::Identical, AxisRelativeDirection::Identical),
                    time: (event.time() / 1000) as u32, // us to ms
                    axis: (horizontal, vertical),
                    v120: {
                        if let (None, None) = (horizontal_discrete, vertical_discrete) {
                            None
                        } else {
                            Some((
                                horizontal_discrete.unwrap_or(0.0) as i32,
                                vertical_discrete.unwrap_or(0.0) as i32,
                            ))
                        }
                    },
                    stop: (false, false),
                },
            );
            pointer.frame(&mut data.state);

            data.state.flutter_engine().send_pointer_event(FlutterPointerEvent {
                struct_size: size_of::<FlutterPointerEvent>(),
                phase: if data.state.flutter_engine().mouse_button_tracker.are_any_buttons_pressed() {
                    FlutterPointerPhase_kMove
                } else {
                    FlutterPointerPhase_kDown
                },
                timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
                x: data.state.mouse_position.0,
                y: data.state.mouse_position.1,
                device: 0,
                signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindScroll,
                scroll_delta_x: horizontal,
                scroll_delta_y: vertical,
                device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
                buttons: data.state.flutter_engine().mouse_button_tracker.get_flutter_button_bitmask(),
                pan_x: 0.0,
                pan_y: 0.0,
                scale: 0.0,
                rotation: 0.0,
            }).unwrap();
        }
        InputEvent::Keyboard { event } => {
            // Update the state of the keyboard.
            // Every key event must be passed through `glfw_key_codes.input_intercept` so that Smithay knows what keys are pressed.
            let keyboard = data.state.keyboard.clone();
            let ((mods, utf32_codepoint), mods_changed) = keyboard.input_intercept::<_, _>(
                &mut data.state,
                event.key_code(),
                event.state(),
                |_, mods, keysym_handle| {
                    // After updating the glfw_key_codes state,
                    // we get the state of the modifiers and the character that was typed.
                    let utf32_codepoint = keysym_handle.modified_sym().key_char();
                    (*mods, utf32_codepoint)
                },
            );

            data.state.flutter_engine.as_mut().unwrap().send_key_event(
                data.state.tx_flutter_handled_key_event.clone(),
                KeyEvent {
                    key_code: event.key_code(),
                    codepoint: utf32_codepoint,
                    state: event.state(),
                    time: event.time_msec(),
                    mods,
                    mods_changed,
                });

            // Initiate key repeat.
            match event.state() {
                KeyState::Pressed => {
                    data.state.key_repeater.down(
                        event.key_code(),
                        utf32_codepoint,
                        // TODO: Use the same values as configured for Wayland clients.
                        Duration::from_millis(200),
                        Duration::from_millis(50),
                    );
                }
                KeyState::Released => {
                    data.state.key_repeater.up(event.key_code());
                }
            }

            if event.key_code() == KEY_ESC as u32 && event.state() == KeyState::Pressed {
                data.state.running.store(false, Ordering::SeqCst);
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
    }
}

fn send_motion_event<BackendData>(data: &mut CalloopData<BackendData>)
    where BackendData: Backend + 'static
{
    data.state.flutter_engine().send_pointer_event(FlutterPointerEvent {
        struct_size: size_of::<FlutterPointerEvent>(),
        phase: if data.state.flutter_engine().mouse_button_tracker.are_any_buttons_pressed() {
            FlutterPointerPhase_kMove
        } else {
            FlutterPointerPhase_kHover
        },
        timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
        x: data.state.mouse_position.0,
        y: data.state.mouse_position.1,
        device: 0,
        signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindNone,
        scroll_delta_x: 0.0,
        scroll_delta_y: 0.0,
        device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
        buttons: data.state.flutter_engine().mouse_button_tracker.get_flutter_button_bitmask(),
        pan_x: 0.0,
        pan_y: 0.0,
        scale: 0.0,
        rotation: 0.0,
    }).unwrap();
}
