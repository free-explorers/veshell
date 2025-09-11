use std::mem::size_of;

use smithay::backend::input::{
    self, AbsolutePositionEvent, Axis, AxisSource, ButtonState, Event, GesturePinchUpdateEvent,
    InputBackend, PointerAxisEvent, PointerButtonEvent, PointerMotionEvent,
};
use smithay::input::pointer::{AxisFrame, ButtonEvent, MotionEvent, RelativeMotionEvent};
use smithay::reexports::wayland_server::protocol::wl_pointer;
use smithay::utils::{Logical, Point, SERIAL_COUNTER};
use tracing::{debug, info};

use crate::backend::Backend;
use crate::flutter_engine::embedder::{
    FlutterPointerDeviceKind, FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
    FlutterPointerDeviceKind_kFlutterPointerDeviceKindTrackpad, FlutterPointerEvent,
    FlutterPointerPhase, FlutterPointerPhase_kDown, FlutterPointerPhase_kHover,
    FlutterPointerPhase_kMove, FlutterPointerPhase_kPanZoomEnd, FlutterPointerPhase_kPanZoomStart,
    FlutterPointerPhase_kPanZoomUpdate, FlutterPointerPhase_kUp,
    FlutterPointerSignalKind_kFlutterPointerSignalKindNone,
    FlutterPointerSignalKind_kFlutterPointerSignalKindScroll,
};
use crate::flutter_engine::view::OutputViewIdWrapper;
use crate::flutter_engine::{view, FlutterEngine};
use crate::settings::MouseAndTouchpadSettings;
use crate::state::State;

impl<BackendData: Backend> State<BackendData> {
    pub fn on_pointer_motion<B: InputBackend>(
        &mut self,
        event: B::PointerMotionEvent,
        device_id: i32,
        view_id: i64,
    ) where
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

        if self.meta_window_state.meta_window_in_gaming_mode.is_some() {
            return;
        }
        let relative_location: Point<f64, Logical> = self.relative_pointer_location();
        self.send_motion_event(relative_location, device_id, view_id)
    }

    pub fn on_pointer_motion_absolute<B: InputBackend>(
        &mut self,
        event: B::PointerMotionAbsoluteEvent,
        device_id: i32,
        view_id: i64,
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
        if self.meta_window_state.meta_window_in_gaming_mode.is_some() {
            return;
        }
        let relative_location: Point<f64, Logical> = self.relative_pointer_location();
        self.send_motion_event(relative_location, device_id, view_id)
    }

    pub fn on_pointer_button<B: InputBackend>(
        &mut self,
        event: B::PointerButtonEvent,
        device_id: i32,
        view_id: i64,
    ) where
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
        if self.meta_window_state.meta_window_in_gaming_mode.is_some() {
            let state = wl_pointer::ButtonState::from(event.state());

            let pointer = self.pointer.clone();
            pointer.button(
                self,
                &ButtonEvent {
                    button: event.button_code(),
                    state: state.try_into().unwrap(),
                    serial: SERIAL_COUNTER.next_serial(),
                    time: event.time_msec(),
                },
            );
            pointer.frame(self);
            return;
        }
        let scale = self
            .space
            .outputs()
            .find(|o| o.user_data().get::<OutputViewIdWrapper>().unwrap().view_id == view_id)
            .unwrap()
            .current_scale()
            .fractional_scale();

        let pointer_location = self.relative_pointer_location();
        self.flutter_engine()
            .send_pointer_event(FlutterPointerEvent {
                struct_size: size_of::<FlutterPointerEvent>(),
                phase,
                timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
                x: pointer_location.x * scale,
                y: pointer_location.y * scale,
                device: device_id,
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
                view_id,
            })
            .unwrap();
    }

    pub fn on_pointer_axis<B: InputBackend>(
        &mut self,
        event: B::PointerAxisEvent,
        device_id: i32,
        view_id: i64,
    ) where
        BackendData: Backend + 'static,
    {
        let horizontal_amount = event.amount(input::Axis::Horizontal).unwrap_or_else(|| {
            event.amount_v120(input::Axis::Horizontal).unwrap_or(0.0) / 120. * 15.
        });
        let vertical_amount = event.amount(input::Axis::Vertical).unwrap_or_else(|| {
            event.amount_v120(input::Axis::Vertical).unwrap_or(0.0) / 120. * 15.
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
        let pointer_location = self.relative_pointer_location();

        // Flutter distinguish Mouse and Trackpad scrolls, so we need to send a separate event for each
        if event.source() == AxisSource::Wheel || event.source() == AxisSource::WheelTilt {
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
                    x: pointer_location.x,
                    y: pointer_location.y,
                    device: device_id,
                    signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindScroll,
                    scroll_delta_x: frame.axis.0 * 58.,
                    scroll_delta_y: frame.axis.1 * 58.,
                    device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
                    buttons: self
                        .flutter_engine()
                        .mouse_button_tracker
                        .get_flutter_button_bitmask(),
                    pan_x: 0.0,
                    pan_y: 0.0,
                    scale: 1.0,
                    rotation: 0.0,
                    view_id,
                })
                .unwrap();
        } else {
            // For Trackpad Flutter expect a PanZoom event
            if (frame.stop.0 && frame.stop.1)
                && self
                    .flutter_engine()
                    .trackpad_scrolling_manager
                    .trackpad_scrolling
            {
                self.flutter_engine_mut()
                    .trackpad_scrolling_manager
                    .stop_scrolling();

                self.send_pointer_pan_zoom_event(
                    device_id,
                    pointer_location.x,
                    pointer_location.y,
                    FlutterPointerPhase_kPanZoomEnd,
                    0.,
                    0.,
                    0.,
                    view_id,
                );
            } else {
                if !self
                    .flutter_engine()
                    .trackpad_scrolling_manager
                    .trackpad_scrolling
                {
                    self.flutter_engine_mut()
                        .trackpad_scrolling_manager
                        .start_scrolling();
                    self.send_pointer_pan_zoom_event(
                        device_id,
                        pointer_location.x,
                        pointer_location.y,
                        FlutterPointerPhase_kPanZoomStart,
                        0.,
                        0.,
                        0.,
                        view_id,
                    );
                }
                self.flutter_engine_mut()
                    .trackpad_scrolling_manager
                    .update_pan(
                        event.amount(Axis::Horizontal).unwrap_or_else(|| 0.0),
                        event.amount(Axis::Vertical).unwrap_or_else(|| 0.0),
                    );
                self.send_pointer_pan_zoom_event(
                    device_id,
                    pointer_location.x,
                    pointer_location.y,
                    FlutterPointerPhase_kPanZoomUpdate,
                    self.flutter_engine().trackpad_scrolling_manager.pan_x,
                    self.flutter_engine().trackpad_scrolling_manager.pan_y,
                    1.,
                    view_id,
                );
            }
        }
    }

    pub fn on_gesture_pinch_begin<B: InputBackend>(
        &mut self,
        event: B::GesturePinchBeginEvent,
        device_id: i32,
        view_id: i64,
    ) {
        let pointer: smithay::input::pointer::PointerHandle<State<BackendData>> =
            self.pointer.clone();

        self.send_pointer_pan_zoom_event(
            device_id,
            pointer.current_location().x,
            pointer.current_location().y,
            FlutterPointerPhase_kPanZoomStart,
            0.,
            0.,
            0.,
            view_id,
        );
    }
    pub fn on_gesture_pinch_update<B: InputBackend>(
        &mut self,
        event: B::GesturePinchUpdateEvent,
        device_id: i32,
        view_id: i64,
    ) {
        let pointer: smithay::input::pointer::PointerHandle<State<BackendData>> =
            self.pointer.clone();
        self.send_pointer_pan_zoom_event(
            device_id,
            pointer.current_location().x,
            pointer.current_location().y,
            FlutterPointerPhase_kPanZoomUpdate,
            event.delta_x(),
            event.delta_y(),
            event.rotation(),
            view_id,
        );
    }
    pub fn on_gesture_pinch_end<B: InputBackend>(
        &mut self,
        _event: B::GesturePinchEndEvent,
        device_id: i32,
        view_id: i64,
    ) {
        let pointer: smithay::input::pointer::PointerHandle<State<BackendData>> =
            self.pointer.clone();
        self.send_pointer_pan_zoom_event(
            device_id,
            pointer.current_location().x,
            pointer.current_location().y,
            FlutterPointerPhase_kPanZoomEnd,
            0.,
            0.,
            0.,
            view_id,
        );
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

    fn relative_pointer_location(&mut self) -> Point<f64, Logical> {
        let location = self.pointer.current_location();
        let output_under_pointer_location = self
            .space
            .output_under(location)
            .next()
            .or_else(|| self.space.outputs().next())
            .unwrap()
            .current_location()
            .to_f64();
        (
            location.x - output_under_pointer_location.x,
            location.y - output_under_pointer_location.y,
        )
            .into()
    }

    fn send_motion_event(&mut self, location: Point<f64, Logical>, device_id: i32, view_id: i64)
    where
        BackendData: Backend + 'static,
    {
        let scale = self
            .space
            .outputs()
            .find(|o| o.user_data().get::<OutputViewIdWrapper>().unwrap().view_id == view_id)
            .unwrap()
            .current_scale()
            .fractional_scale();

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
                x: location.x * scale,
                y: location.y * scale,
                device: device_id,
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
                view_id,
            })
            .unwrap();
    }

    fn send_pointer_pan_zoom_event(
        &mut self,
        device_id: i32,
        x: f64,
        y: f64,
        phase: FlutterPointerPhase,
        pan_x: f64,
        pan_y: f64,
        rotation: f64,
        view_id: i64,
    ) {
        let scale = self
            .space
            .outputs()
            .find(|o| o.user_data().get::<OutputViewIdWrapper>().unwrap().view_id == view_id)
            .unwrap()
            .current_scale()
            .fractional_scale();
        self.flutter_engine()
            .send_pointer_event(FlutterPointerEvent {
                struct_size: size_of::<FlutterPointerEvent>(),
                phase,
                timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
                x,
                y,
                device: device_id,
                signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindNone,
                scroll_delta_x: 0.0,
                scroll_delta_y: 0.0,
                device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindTrackpad,
                buttons: 0,
                pan_x,
                pan_y,
                scale,
                rotation,
                view_id,
            })
            .unwrap();
    }
}
