use std::mem::size_of;

use smithay::backend::input::{
    self, AbsolutePositionEvent, Axis, AxisSource, ButtonState, Event, GesturePinchUpdateEvent,
    InputBackend, PointerAxisEvent, PointerButtonEvent, PointerMotionEvent,
};
use smithay::input::pointer::{AxisFrame, ButtonEvent, MotionEvent, RelativeMotionEvent};
use smithay::reexports::wayland_server::protocol::wl_pointer;
use smithay::utils::{Logical, Point, Rectangle, SERIAL_COUNTER};
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
use crate::flutter_engine::view::view_id_for_output;
use crate::flutter_engine::{view, FlutterEngine};
use crate::focus::PointerFocusTarget;
use crate::settings::MouseAndTouchpadSettings;
use crate::state::State;

/// Bounding box of a set of output geometries, in global logical coordinates.
///
/// The pointer is confined to this box. It is derived from the actual output
/// geometry instead of assuming a layout anchored at `(0, 0)` in a single
/// horizontal row, so arbitrary arrangements (vertical stacks, gaps, negative
/// origins) keep every monitor reachable.
fn output_bounds_from(
    geometries: impl Iterator<Item = Rectangle<i32, Logical>>,
) -> Option<Rectangle<i32, Logical>> {
    geometries.reduce(|bounds, geometry| bounds.merge(geometry))
}

/// Confines `pos` to `bounds`.
fn clamp_to_bounds(
    pos: Point<f64, Logical>,
    bounds: Rectangle<i32, Logical>,
) -> Point<f64, Logical> {
    let min_x = bounds.loc.x as f64;
    let min_y = bounds.loc.y as f64;
    let max_x = (bounds.loc.x + bounds.size.w) as f64;
    let max_y = (bounds.loc.y + bounds.size.h) as f64;
    (pos.x.clamp(min_x, max_x), pos.y.clamp(min_y, max_y)).into()
}

impl<BackendData: Backend> State<BackendData> {
    pub fn on_pointer_motion<B: InputBackend>(
        &mut self,
        event: B::PointerMotionEvent,
        device_id: i32,
        _view_id: i64,
    ) where
        BackendData: Backend + 'static,
    {
        self.request_render();
        let pointer: smithay::input::pointer::PointerHandle<State<BackendData>> =
            self.pointer.clone();
        let mut pointer_location = self.pointer.current_location();

        // While a screenshot session is active the desktop is frozen: the
        // pointer only drives the native selection, nothing is sent to
        // Flutter or Wayland clients. The Smithay pointer keeps its frozen
        // position; the session accumulates the deltas itself.
        if self.capture_state.session.is_some() {
            crate::capture::capture_pointer_motion_delta(self, event.delta());
            return;
        }

        // The game owns the pointer while it is active: derive the focus from
        // its own surface so a stray shell update cannot starve it of motion.
        if self.meta_window_state.meta_window_in_gaming_mode.is_some() {
            self.pointer_focus = self.gaming_pointer_focus();
        }

        // clamp to screen limits
        pointer_location = self.clamp_coords(pointer_location);

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
        let current_view_id = self.view_id_under_pointer();
        self.focus_view_under_pointer();
        let view_id = if self
            .flutter_engine()
            .mouse_button_tracker
            .are_any_buttons_pressed()
        {
            self.pointer_gesture_view_id.or(current_view_id)
        } else {
            current_view_id
        };
        let Some(view_id) = view_id else {
            debug!("dropping pointer motion: pointer is not over a mapped output");
            return;
        };
        self.send_motion_event(device_id, view_id)
    }

    pub fn on_pointer_motion_absolute<B: InputBackend>(
        &mut self,
        event: B::PointerMotionAbsoluteEvent,
        device_id: i32,
        _view_id: i64,
    ) where
        BackendData: Backend + 'static,
    {
        self.request_render();
        let serial = SERIAL_COUNTER.next_serial();
        let Some(bounds) = self.output_bounds() else {
            debug!("dropping absolute pointer motion: no mapped output");
            return;
        };

        // Map the normalised absolute position onto the outputs' bounding box,
        // which is not necessarily anchored at (0, 0).
        let max_x = bounds.size.w;
        let max_y = bounds.size.h;
        let mut pointer_location = (
            bounds.loc.x as f64 + event.x_transformed(max_x),
            bounds.loc.y as f64 + event.y_transformed(max_y),
        )
            .into();

        // clamp to screen limits
        pointer_location = self.clamp_coords(pointer_location);

        if self.capture_state.session.is_some() {
            crate::capture::capture_pointer_motion_to(self, pointer_location);
            return;
        }

        // See `on_pointer_motion`: keep the active game's pointer focus derived
        // from its surface.
        if self.meta_window_state.meta_window_in_gaming_mode.is_some() {
            self.pointer_focus = self.gaming_pointer_focus();
        }

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
        let current_view_id = self.view_id_under_pointer();
        self.focus_view_under_pointer();
        let view_id = if self
            .flutter_engine()
            .mouse_button_tracker
            .are_any_buttons_pressed()
        {
            self.pointer_gesture_view_id.or(current_view_id)
        } else {
            current_view_id
        };
        let Some(view_id) = view_id else {
            debug!("dropping pointer motion: pointer is not over a mapped output");
            return;
        };
        self.send_motion_event(device_id, view_id)
    }

    pub fn on_pointer_button<B: InputBackend>(
        &mut self,
        event: B::PointerButtonEvent,
        device_id: i32,
        view_id: Option<i64>,
    ) where
        BackendData: Backend + 'static,
    {
        self.request_render();
        // While a screenshot session is active the drag is native: the
        // button never reaches the frozen desktop below. Positions come
        // from the session's own tracking (the Smithay pointer is frozen).
        if self.capture_state.session.is_some() {
            let button_code = event.button_code();
            if event.state() == ButtonState::Pressed {
                crate::capture::capture_pointer_press(self, button_code);
            } else {
                crate::capture::capture_pointer_release(self, button_code);
            }
            return;
        }

        // Gaming mode forwards the button straight to the client. It must not
        // touch the Flutter button tracker: those events never reach Flutter,
        // and a press tracked here would desync the next Flutter event.
        if self.meta_window_state.meta_window_in_gaming_mode.is_some() {
            let state = wl_pointer::ButtonState::from(event.state());

            debug!(
                focus = ?self.pointer_focus,
                button = event.button_code(),
                "gaming pointer button"
            );
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

        let had_buttons_pressed = self
            .flutter_engine()
            .mouse_button_tracker
            .are_any_buttons_pressed();
        let event_view_id = self.pointer_gesture_view_id.or(view_id);
        let phase = if event.state() == ButtonState::Pressed {
            let _ = self
                .flutter_engine_mut()
                .mouse_button_tracker
                .press(event.button_code() as u16);
            if had_buttons_pressed {
                FlutterPointerPhase_kMove
            } else {
                self.pointer_gesture_view_id = event_view_id;
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
        if event.state() == ButtonState::Released
            && !self
                .flutter_engine()
                .mouse_button_tracker
                .are_any_buttons_pressed()
        {
            self.pointer_gesture_view_id = None;
        }
        // The button tracker is updated above even when there is no view, so a
        // button released between outputs cannot get stuck. Only the Flutter
        // event is dropped, so input never reaches an unrelated view.
        let Some(event_view_id) = event_view_id else {
            debug!("dropping pointer button: pointer is not over a mapped output");
            return;
        };
        let Some(scale) = self.scale_for_view(event_view_id) else {
            debug!(
                view_id = event_view_id,
                "dropping pointer button: no output owns view"
            );
            return;
        };
        let Some(pointer_location) = self.relative_pointer_location_for_view(event_view_id) else {
            debug!(
                view_id = event_view_id,
                "dropping pointer button: no geometry for view output"
            );
            return;
        };
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
                view_id: event_view_id,
                pressure: 0.0,
                pressure_min: 0.0,
                pressure_max: 0.0,
            })
            .unwrap();
    }

    pub fn on_pointer_axis<B: InputBackend>(
        &mut self,
        event: B::PointerAxisEvent,
        device_id: i32,
        view_id: Option<i64>,
    ) where
        BackendData: Backend + 'static,
    {
        self.request_render();
        // Scroll events are irrelevant while the desktop is frozen for a
        // screenshot selection.
        if self.capture_state.session.is_some() {
            return;
        }
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

        // Gaming mode already delivered the axis to the focused client; keep it
        // out of Flutter, like motion and buttons.
        if self.meta_window_state.meta_window_in_gaming_mode.is_some() {
            return;
        }

        // Flutter distinguish Mouse and Trackpad scrolls, so we need to send a separate event for each
        if event.source() == AxisSource::Wheel || event.source() == AxisSource::WheelTilt {
            let Some(view_id) = view_id else {
                debug!("dropping wheel scroll: pointer is not over a mapped output");
                return;
            };
            let Some(pointer_location) = self.relative_pointer_location_for_view(view_id) else {
                debug!(
                    view_id,
                    "dropping wheel scroll: no geometry for view output"
                );
                return;
            };
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
                    pressure: 0.0,
                    pressure_min: 0.0,
                    pressure_max: 0.0,
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

                let gesture_view_id = self.pointer_gesture_view_id.or(view_id);
                self.send_pointer_pan_zoom_event(
                    device_id,
                    FlutterPointerPhase_kPanZoomEnd,
                    0.,
                    0.,
                    0.,
                    gesture_view_id,
                );
                self.pointer_gesture_view_id = None;
            } else {
                let started = !self
                    .flutter_engine()
                    .trackpad_scrolling_manager
                    .trackpad_scrolling;
                if started {
                    self.flutter_engine_mut()
                        .trackpad_scrolling_manager
                        .start_scrolling();
                    self.pointer_gesture_view_id = view_id;
                }
                let gesture_view_id = self.pointer_gesture_view_id.or(view_id);
                if started {
                    self.send_pointer_pan_zoom_event(
                        device_id,
                        FlutterPointerPhase_kPanZoomStart,
                        0.,
                        0.,
                        0.,
                        gesture_view_id,
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
                    FlutterPointerPhase_kPanZoomUpdate,
                    self.flutter_engine().trackpad_scrolling_manager.pan_x,
                    self.flutter_engine().trackpad_scrolling_manager.pan_y,
                    1.,
                    gesture_view_id,
                );
            }
        }
    }

    pub fn on_gesture_pinch_begin<B: InputBackend>(
        &mut self,
        event: B::GesturePinchBeginEvent,
        device_id: i32,
        view_id: Option<i64>,
    ) {
        self.pointer_gesture_view_id = view_id;
        self.send_pointer_pan_zoom_event(
            device_id,
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
        view_id: Option<i64>,
    ) {
        let gesture_view_id = self.pointer_gesture_view_id.or(view_id);
        self.send_pointer_pan_zoom_event(
            device_id,
            FlutterPointerPhase_kPanZoomUpdate,
            event.delta_x(),
            event.delta_y(),
            event.rotation(),
            gesture_view_id,
        );
    }
    pub fn on_gesture_pinch_end<B: InputBackend>(
        &mut self,
        _event: B::GesturePinchEndEvent,
        device_id: i32,
        view_id: Option<i64>,
    ) {
        let gesture_view_id = self.pointer_gesture_view_id.or(view_id);
        self.send_pointer_pan_zoom_event(
            device_id,
            FlutterPointerPhase_kPanZoomEnd,
            0.,
            0.,
            0.,
            gesture_view_id,
        );
        self.pointer_gesture_view_id = None;
    }

    /// Pointer focus for the window that owns the input in gaming mode.
    ///
    /// Derived from the gaming window's own surface instead of trusting the
    /// stored `pointer_focus`: as long as the game owns the output it is the
    /// only valid pointer target, so motion and buttons keep flowing even if a
    /// shell-side focus update slipped through.
    pub(crate) fn gaming_pointer_focus(&self) -> Option<(PointerFocusTarget, Point<f64, Logical>)> {
        let meta_window_id = self.meta_window_state.meta_window_in_gaming_mode.as_ref()?;
        let meta_window = self.meta_window_state.meta_windows.get(meta_window_id)?;
        let surface = self.surfaces.get(&meta_window.surface_id)?;
        let origin = meta_window
            .current_output
            .as_deref()
            .and_then(|name| self.space.outputs().find(|output| output.name() == name))
            .and_then(|output| self.space.output_geometry(output))
            .map(|geometry| geometry.loc.to_f64())
            .unwrap_or_else(|| (0.0, 0.0).into());
        Some((PointerFocusTarget::from(surface), origin))
    }

    /// Re-drives the Smithay pointer with the current `pointer_focus`.
    ///
    /// Flutter is the authority on which surface is under the cursor, but
    /// Smithay only learns about a focus change through `PointerHandle::motion`.
    /// When a window slides under a stationary cursor (keyboard window or
    /// workspace navigation), Flutter reports the new surface without any
    /// physical motion. Without this refresh Smithay keeps routing `axis`
    /// (scroll), `button` and frames to the previously focused surface until
    /// the user moves the pointer.
    pub(crate) fn refresh_pointer_focus(&mut self)
    where
        BackendData: Backend + 'static,
    {
        let pointer = self.pointer.clone();
        let focus = self.pointer_focus.clone();
        let event = MotionEvent {
            location: pointer.current_location(),
            serial: SERIAL_COUNTER.next_serial(),
            time: self.frame_timestamp_millis(),
        };
        pointer.motion(self, focus, &event);
        self.register_frame();
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

    /// Bounding box of every mapped output, in global logical coordinates.
    ///
    /// The pointer is confined to this box. It is derived from the actual
    /// output geometry instead of assuming a layout anchored at `(0, 0)` in a
    /// single horizontal row, so arbitrary arrangements (vertical stacks,
    /// gaps, negative origins) keep every monitor reachable.
    fn output_bounds(&self) -> Option<Rectangle<i32, Logical>> {
        output_bounds_from(
            self.space
                .outputs()
                .filter_map(|output| self.space.output_geometry(output)),
        )
    }

    fn clamp_coords(&mut self, pos: Point<f64, Logical>) -> Point<f64, Logical>
    where
        BackendData: Backend + 'static,
    {
        match self.output_bounds() {
            Some(bounds) => clamp_to_bounds(pos, bounds),
            None => pos,
        }
    }

    /// Fractional scale of the output that owns `view_id`, if any.
    fn scale_for_view(&self, view_id: i64) -> Option<f64> {
        self.space
            .outputs()
            .find(|output| view_id_for_output(output) == Some(view_id))
            .map(|output| output.current_scale().fractional_scale())
    }

    /// Pointer location relative to the output that owns `view_id`.
    ///
    /// Returns `None` when no mapped output owns the view (the view was torn
    /// down, or the connector is leased), so input is dropped instead of being
    /// routed with coordinates taken from an unrelated output.
    fn relative_pointer_location_for_view(&self, view_id: i64) -> Option<Point<f64, Logical>> {
        let location = self.pointer.current_location();

        // When `view_id` belongs to a monitor mirrored by the output under the
        // pointer, map the pointer proportionally from the follower's logical
        // box to the source's so input lands at the same relative spot.
        if let Some(follower) = self.space.output_under(location).next() {
            if let Some(source) = self.mirror_source(follower) {
                if view_id_for_output(&source) == Some(view_id) {
                    let follower_geometry = self.space.output_geometry(follower)?.to_f64();
                    let source_geometry = self.space.output_geometry(&source)?.to_f64();
                    if follower_geometry.size.w > 0.0 && follower_geometry.size.h > 0.0 {
                        let nx = (location.x - follower_geometry.loc.x) / follower_geometry.size.w;
                        let ny = (location.y - follower_geometry.loc.y) / follower_geometry.size.h;
                        return Some(
                            (nx * source_geometry.size.w, ny * source_geometry.size.h).into(),
                        );
                    }
                }
            }
        }

        let output_geometry = self
            .space
            .outputs()
            .find(|output| view_id_for_output(output) == Some(view_id))
            .and_then(|output| self.space.output_geometry(output))?
            .to_f64();
        Some(
            (
                location.x - output_geometry.loc.x,
                location.y - output_geometry.loc.y,
            )
                .into(),
        )
    }

    pub(crate) fn view_id_under_pointer(&self) -> Option<i64> {
        let output = self
            .space
            .output_under(self.pointer.current_location())
            .next()?;
        // A mirroring output routes input to the monitor it mirrors.
        let target = self.mirror_source(output).unwrap_or_else(|| output.clone());
        view_id_for_output(&target)
    }

    /// Makes the output view under the pointer the platform-focused view.
    ///
    /// This is the compositor side of the focus source of truth: moving the
    /// pointer onto a monitor focuses it even when no Flutter widget focus
    /// transition happens, so trusted prompts and window placement follow the
    /// pointer. The engine is only notified when the view actually changes.
    pub(crate) fn focus_view_under_pointer(&mut self) {
        let view_id = self.view_id_under_pointer();
        self.flutter_engine_mut().set_focused_view(view_id);
    }

    fn send_motion_event(&mut self, device_id: i32, view_id: i64)
    where
        BackendData: Backend + 'static,
    {
        let Some(scale) = self.scale_for_view(view_id) else {
            debug!(view_id, "dropping pointer motion: no output owns view");
            return;
        };
        let Some(location) = self.relative_pointer_location_for_view(view_id) else {
            debug!(
                view_id,
                "dropping pointer motion: no geometry for view output"
            );
            return;
        };

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
                pressure: 0.0,
                pressure_min: 0.0,
                pressure_max: 0.0,
            })
            .unwrap();
    }

    fn send_pointer_pan_zoom_event(
        &mut self,
        device_id: i32,
        phase: FlutterPointerPhase,
        pan_x: f64,
        pan_y: f64,
        rotation: f64,
        view_id: Option<i64>,
    ) {
        let Some(view_id) = view_id else {
            debug!("dropping pointer pan/zoom: pointer is not over a mapped output");
            return;
        };
        let Some(scale) = self.scale_for_view(view_id) else {
            debug!(view_id, "dropping pointer pan/zoom: no output owns view");
            return;
        };
        let Some(location) = self.relative_pointer_location_for_view(view_id) else {
            debug!(
                view_id,
                "dropping pointer pan/zoom: no geometry for view output"
            );
            return;
        };
        self.flutter_engine()
            .send_pointer_event(FlutterPointerEvent {
                struct_size: size_of::<FlutterPointerEvent>(),
                phase,
                timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
                x: location.x,
                y: location.y,
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
                pressure: 0.0,
                pressure_min: 0.0,
                pressure_max: 0.0,
            })
            .unwrap();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rect(x: i32, y: i32, w: i32, h: i32) -> Rectangle<i32, Logical> {
        Rectangle::new((x, y).into(), (w, h).into())
    }

    #[test]
    fn bounds_span_a_horizontal_row() {
        let bounds =
            output_bounds_from([rect(0, 0, 1920, 1080), rect(1920, 0, 2560, 1440)].into_iter());

        assert_eq!(bounds, Some(rect(0, 0, 4480, 1440)));
    }

    #[test]
    fn bounds_span_a_vertical_stack() {
        let bounds =
            output_bounds_from([rect(0, 0, 1920, 1080), rect(0, 1080, 1920, 1080)].into_iter());

        assert_eq!(bounds, Some(rect(0, 0, 1920, 2160)));
    }

    #[test]
    fn bounds_include_a_negative_origin() {
        let bounds =
            output_bounds_from([rect(-1920, 0, 1920, 1080), rect(0, 0, 1920, 1080)].into_iter());

        assert_eq!(bounds, Some(rect(-1920, 0, 3840, 1080)));
    }

    #[test]
    fn bounds_are_none_without_outputs() {
        assert_eq!(output_bounds_from([].into_iter()), None);
    }

    #[test]
    fn clamp_keeps_a_vertical_stack_reachable() {
        let bounds = rect(0, 0, 1920, 2160);

        assert_eq!(
            clamp_to_bounds((500.0, 2000.0).into(), bounds),
            (500.0, 2000.0).into()
        );
        assert_eq!(
            clamp_to_bounds((500.0, 5000.0).into(), bounds),
            (500.0, 2160.0).into()
        );
    }

    #[test]
    fn clamp_respects_a_negative_origin() {
        let bounds = rect(-1920, 0, 3840, 1080);

        assert_eq!(
            clamp_to_bounds((-5000.0, 100.0).into(), bounds),
            (-1920.0, 100.0).into()
        );
    }
}
