use std::mem::size_of;

use smithay::backend::input::{
    self, AbsolutePositionEvent, Axis, AxisSource, ButtonState, Event, InputBackend,
    KeyboardKeyEvent, PointerAxisEvent, PointerButtonEvent, PointerMotionEvent,
};
use smithay::input::pointer::{AxisFrame, MotionEvent, RelativeMotionEvent};
use smithay::utils::{Logical, Point, SERIAL_COUNTER};
use tracing::info;

use crate::backend::Backend;
use crate::flutter_engine::embedder::{
    FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse, FlutterPointerEvent,
    FlutterPointerPhase_kDown, FlutterPointerPhase_kHover, FlutterPointerPhase_kMove,
    FlutterPointerPhase_kUp, FlutterPointerSignalKind_kFlutterPointerSignalKindNone,
    FlutterPointerSignalKind_kFlutterPointerSignalKindScroll,
};
use crate::flutter_engine::FlutterEngine;
use crate::state::State;

impl<BackendData: Backend> State<BackendData> {
    pub fn on_pointer_motion<B: InputBackend>(&mut self, event: B::PointerMotionEvent)
    where
        BackendData: Backend + 'static,
    {
        let pointer: smithay::input::pointer::PointerHandle<State<BackendData>> =
            self.pointer.clone();

        let mut pointer_location = self.pointer.current_location();

        pointer.relative_motion(
            self,
            self.pointer_focus.clone(),
            &RelativeMotionEvent {
                delta: event.delta(),
                delta_unaccel: event.delta_unaccel(),
                utime: event.time(),
            },
        );

        pointer_location += event.delta();

        // clamp to screen limits
        pointer_location = self.clamp_coords(pointer_location);

        pointer.motion(
            self,
            self.pointer_focus.clone(),
            &MotionEvent {
                location: pointer_location,
                serial: SERIAL_COUNTER.next_serial(),
                time: event.time_msec(),
            },
        );
        self.register_frame();

        self.send_motion_event(pointer_location)
    }

    pub fn on_pointer_motion_absolute<B: InputBackend>(
        &mut self,
        event: B::PointerMotionAbsoluteEvent,
    ) where
        BackendData: Backend + 'static,
    {
        let serial = SERIAL_COUNTER.next_serial();
        let outputs: Vec<smithay::output::Output> =
            self.space.outputs().cloned().collect::<Vec<_>>();
        let max_x = outputs.into_iter().fold(0, |acc, o| {
            acc + self.space.output_geometry(&o).unwrap().size.w
        });

        let max_h_output = self
            .space
            .outputs()
            .max_by_key(|o| self.space.output_geometry(o).unwrap().size.h)
            .unwrap();

        let max_y = self.space.output_geometry(max_h_output).unwrap().size.h;

        let mut pointer_location = (event.x_transformed(max_x), event.y_transformed(max_y)).into();

        // clamp to screen limits
        pointer_location = self.clamp_coords(pointer_location);

        let pointer = self.pointer.clone();
        pointer.motion(
            self,
            self.pointer_focus.clone(),
            &MotionEvent {
                location: pointer_location,
                serial,
                time: event.time_msec(),
            },
        );
        self.register_frame();

        self.send_motion_event(pointer_location)
    }

    pub fn on_pointer_button<B: InputBackend>(&mut self, event: B::PointerButtonEvent)
    where
        BackendData: Backend + 'static,
    {
        let phase = if event.state() == ButtonState::Pressed {
            let are_any_buttons_pressed = self
                .flutter_engine()
                .mouse_button_tracker
                .are_any_buttons_pressed();
            let _ = self
                .flutter_engine_mut()
                .mouse_button_tracker
                .press(event.button_code() as u16);
            if are_any_buttons_pressed {
                FlutterPointerPhase_kMove
            } else {
                FlutterPointerPhase_kDown
            }
        } else {
            let _ = self
                .flutter_engine_mut()
                .mouse_button_tracker
                .release(event.button_code() as u16);
            if self
                .flutter_engine()
                .mouse_button_tracker
                .are_any_buttons_pressed()
            {
                FlutterPointerPhase_kMove
            } else {
                FlutterPointerPhase_kUp
            }
        };
        info!("PointerButton {:?}", event.button_code());
        self.flutter_engine()
            .send_pointer_event(FlutterPointerEvent {
                struct_size: size_of::<FlutterPointerEvent>(),
                phase,
                timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
                x: self.pointer.current_location().x,
                y: self.pointer.current_location().y,
                device: 0,
                signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindNone,
                scroll_delta_x: 0.0,
                scroll_delta_y: 0.0,
                device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
                buttons: self
                    .flutter_engine()
                    .mouse_button_tracker
                    .get_flutter_button_bitmask(),
                pan_x: 0.0,
                pan_y: 0.0,
                scale: 1.0,
                rotation: 0.0,
                view_id: 0,
            })
            .unwrap();
    }

    pub fn on_pointer_axis<B: InputBackend>(&mut self, event: B::PointerAxisEvent)
    where
        BackendData: Backend + 'static,
    {
        let horizontal_amount = event.amount(input::Axis::Horizontal).unwrap_or_else(|| {
            event.amount_v120(input::Axis::Horizontal).unwrap_or(0.0) * 15.0 / 120.
        });
        let vertical_amount = event.amount(input::Axis::Vertical).unwrap_or_else(|| {
            event.amount_v120(input::Axis::Vertical).unwrap_or(0.0) * 15.0 / 120.
        });
        let horizontal_amount_discrete = event.amount_v120(input::Axis::Horizontal);
        let vertical_amount_discrete = event.amount_v120(input::Axis::Vertical);

        let mut frame = AxisFrame::new(event.time_msec()).source(event.source());
        if horizontal_amount != 0.0 {
            frame = frame
                .relative_direction(Axis::Horizontal, event.relative_direction(Axis::Horizontal));
            frame = frame.value(Axis::Horizontal, horizontal_amount);
            if let Some(discrete) = horizontal_amount_discrete {
                frame = frame.v120(Axis::Horizontal, discrete as i32);
            }
        }
        if vertical_amount != 0.0 {
            frame =
                frame.relative_direction(Axis::Vertical, event.relative_direction(Axis::Vertical));
            frame = frame.value(Axis::Vertical, vertical_amount);
            if let Some(discrete) = vertical_amount_discrete {
                frame = frame.v120(Axis::Vertical, discrete as i32);
            }
        }
        if event.source() == AxisSource::Finger {
            if event.amount(Axis::Horizontal) == Some(0.0) {
                frame = frame.stop(Axis::Horizontal);
            }
            if event.amount(Axis::Vertical) == Some(0.0) {
                frame = frame.stop(Axis::Vertical);
            }
        }
        let pointer = self.pointer.clone();
        pointer.axis(self, frame);
        self.register_frame();

        self.flutter_engine()
            .send_pointer_event(FlutterPointerEvent {
                struct_size: size_of::<FlutterPointerEvent>(),
                phase: if self
                    .flutter_engine()
                    .mouse_button_tracker
                    .are_any_buttons_pressed()
                {
                    FlutterPointerPhase_kMove
                } else {
                    FlutterPointerPhase_kDown
                },
                timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
                x: self.pointer.current_location().x,
                y: self.pointer.current_location().y,
                device: 0,
                signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindScroll,
                scroll_delta_x: frame.axis.0,
                scroll_delta_y: frame.axis.1,
                device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
                buttons: self
                    .flutter_engine()
                    .mouse_button_tracker
                    .get_flutter_button_bitmask(),
                pan_x: 0.0,
                pan_y: 0.0,
                scale: 1.0,
                rotation: 0.0,
                view_id: 0,
            })
            .unwrap();
    }

    fn register_frame(&mut self) {
        if self.pointer_frame_pending {
            return;
        }
        self.loop_handle.insert_idle(move |data| {
            data.pointer.clone().frame(data);
            data.pointer_frame_pending = false;
        });
        self.pointer_frame_pending = true;
    }

    fn clamp_coords(&mut self, pos: Point<f64, Logical>) -> Point<f64, Logical>
    where
        BackendData: Backend + 'static,
    {
        if self.space.outputs().next().is_none() {
            return pos;
        }

        let (pos_x, pos_y) = pos.into();
        let max_x = self.space.outputs().fold(0, |acc, o| {
            acc + self.space.output_geometry(o).unwrap().size.w
        });
        let clamped_x = pos_x.clamp(0.0, max_x as f64);
        let max_y = self
            .space
            .outputs()
            .find(|o| {
                let geo = self.space.output_geometry(o).unwrap();
                geo.contains((clamped_x as i32, 0))
            })
            .map(|o| self.space.output_geometry(o).unwrap().size.h);

        if let Some(max_y) = max_y {
            let clamped_y = pos_y.clamp(0.0, max_y as f64);
            (clamped_x, clamped_y).into()
        } else {
            (clamped_x, pos_y).into()
        }
    }

    fn send_motion_event(&mut self, location: Point<f64, Logical>)
    where
        BackendData: Backend + 'static,
    {
        self.flutter_engine()
            .send_pointer_event(FlutterPointerEvent {
                struct_size: size_of::<FlutterPointerEvent>(),
                phase: if self
                    .flutter_engine()
                    .mouse_button_tracker
                    .are_any_buttons_pressed()
                {
                    FlutterPointerPhase_kMove
                } else {
                    FlutterPointerPhase_kHover
                },
                timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
                x: location.x,
                y: location.y,
                device: 0,
                signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindNone,
                scroll_delta_x: 0.0,
                scroll_delta_y: 0.0,
                device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
                buttons: self
                    .flutter_engine()
                    .mouse_button_tracker
                    .get_flutter_button_bitmask(),
                pan_x: 0.0,
                pan_y: 0.0,
                scale: 1.0,
                rotation: 0.0,
                view_id: 0,
            })
            .unwrap();
    }
}
