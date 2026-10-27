use std::mem::size_of;

use smithay::backend::input::{
    self, AbsolutePositionEvent, Axis, AxisSource, ButtonState, Event, GesturePinchUpdateEvent,
    InputBackend, PointerAxisEvent, PointerButtonEvent, PointerMotionEvent,
};
use smithay::input::pointer::{AxisFrame, ButtonEvent, MotionEvent, RelativeMotionEvent};
use smithay::reexports::wayland_server::protocol::wl_pointer;
use smithay::utils::{Logical, Point, Rectangle, SERIAL_COUNTER};
use smithay::wayland::seat::WaylandFocus;
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
use crate::settings::{MouseAndTouchpadSettings, DEFAULT_WHEEL_SCROLL_PIXELS_PER_DETENT};
use crate::state::PopupPointerGrab;
use crate::state::State;
use crate::wayland::wayland::get_surface_id;

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

/// Wheel detents covered by one axis of an [`AxisFrame`].
///
/// libinput reports wheel movement either as an angle in degrees (15 or 20
/// degrees per detent, depending on the device) or as a v120 value (always 120
/// across the whole 0..120 range). Preferring v120 keeps every wheel scrolling
/// the same distance per detent; the degrees fallback assumes the common 15
/// degree wheel.
fn wheel_detents(degrees: f64, v120: Option<f64>) -> f64 {
    match v120 {
        Some(v120) if v120 != 0.0 => v120 / 120.0,
        _ => degrees / 15.0,
    }
}

/// Physical pixels a number of wheel detents scrolls.
///
/// `scroll_factor` is `mouseAndTouchpad.wheelScrollFactor`: it scales the
/// shell's default step (`DEFAULT_WHEEL_SCROLL_PIXELS_PER_DETENT` logical
/// pixels). Flutter divides the result by the device pixel ratio, so it is
/// multiplied by the output `scale` here.
fn wheel_physical_pixels(detents: f64, scroll_factor: f64, scale: f64) -> f64 {
    detents * f64::from(DEFAULT_WHEEL_SCROLL_PIXELS_PER_DETENT) * scroll_factor * scale
}

/// Scales the wheel movement forwarded to Wayland/X11 clients by `factor`.
///
/// Client scroll is expressed in toolkit-relative units (`wl_pointer.axis`,
/// where Xwayland and Wayland clients derive "clicks" from v120 = 120 per
/// detent), so it only ever sees the factor, not the shell's pixel step. This
/// matches KWin, Hyprland and labwc, which multiply both the axis value and the
/// v120 value by a `scroll_factor`. Only wheel sources are touched: touchpad and
/// continuous scrolling use the same axis field but keep their own scale. The
/// frame is `Copy`, so the caller keeps the unscaled one for Flutter.
fn scale_client_wheel_frame(mut frame: AxisFrame, factor: f64) -> AxisFrame {
    if factor == 1.0
        || !matches!(
            frame.source,
            Some(AxisSource::Wheel | AxisSource::WheelTilt)
        )
    {
        return frame;
    }
    frame.axis.0 *= factor;
    frame.axis.1 *= factor;
    if let Some((x, y)) = frame.v120.as_mut() {
        *x = (*x as f64 * factor).round() as i32;
        *y = (*y as f64 * factor).round() as i32;
    }
    frame
}

impl<BackendData: Backend> State<BackendData> {
    /// Applies one pointer-motion sample to an active floating move/resize.
    ///
    /// The compositor owns the pointer during either gesture: the client must
    /// not receive the motion, and the resulting placement is updated from the
    /// same sample. Returns whether a gesture consumed the motion.
    fn consume_floating_gesture_motion(
        &mut self,
        pointer_location: Point<f64, Logical>,
        time: u32,
    ) -> bool {
        if self.floating_move.is_none() && self.floating_resize.is_none() {
            return false;
        }
        let pointer = self.pointer.clone();
        let focus: Option<(PointerFocusTarget, Point<f64, Logical>)> = None;
        pointer.motion(
            self,
            focus,
            &MotionEvent {
                location: pointer_location,
                serial: SERIAL_COUNTER.next_serial(),
                time,
            },
        );
        if self.floating_move.is_some() {
            self.update_floating_move(pointer_location);
        } else {
            self.update_floating_resize(pointer_location);
        }
        self.register_frame();
        crate::capture::on_pointer_motion_for_recording(self);
        crate::portal::service::on_pointer_motion(self);
        true
    }

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
        if self.gaming_input_active() {
            self.pointer_focus = self.gaming_pointer_focus();
        }

        // clamp to screen limits
        pointer_location = self.clamp_coords(pointer_location);

        // A floating move/resize owns the pointer like a compositor grab: do
        // not forward the motion to the client while the window follows it.
        if self.floating_move.is_some() || self.floating_resize.is_some() {
            let location = self.clamp_coords(pointer_location + event.delta());
            self.consume_floating_gesture_motion(location, event.time_msec());
            return;
        }

        pointer.relative_motion(
            self,
            self.client_pointer_focus(),
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
            self.client_pointer_focus(),
            &MotionEvent {
                location: pointer_location,
                serial: SERIAL_COUNTER.next_serial(),
                time: event.time_msec(),
            },
        );
        self.register_frame();
        // The pointer moved: a live recording and any embedded-cursor screen
        // cast on this output need a fresh frame even when the desktop under
        // them is otherwise unchanged.
        crate::capture::on_pointer_motion_for_recording(self);
        crate::portal::service::on_pointer_motion(self);

        if self.gaming_input_active() {
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
        if self.gaming_input_active() {
            self.pointer_focus = self.gaming_pointer_focus();
        }

        // See `on_pointer_motion`: an active floating gesture consumes the
        // motion instead of forwarding it to the client.
        if self.consume_floating_gesture_motion(pointer_location, event.time_msec()) {
            return;
        }

        let pointer = self.pointer.clone();
        pointer.motion(
            self,
            self.client_pointer_focus(),
            &MotionEvent {
                location: pointer_location,
                serial,
                time: event.time_msec(),
            },
        );
        self.register_frame();
        // See `on_pointer_motion`: refresh live recording and embedded-cursor
        // screen-cast pointer frames.
        crate::capture::on_pointer_motion_for_recording(self);
        crate::portal::service::on_pointer_motion(self);
        if self.gaming_input_active() {
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
        if self.gaming_input_active() {
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

        let had_buttons_pressed = self
            .flutter_engine()
            .mouse_button_tracker
            .are_any_buttons_pressed();
        // X11 does not report XGrabPointer. The only observable start of an
        // override-redirect popup drag is the button press on its surface;
        // record that owner so Flutter hover cannot steal the pointer basis
        // while the configure stream drives the popup.
        if event.state() == ButtonState::Pressed {
            self.popup_pointer_grab = self.pointer_focus.as_ref().and_then(|(target, _)| {
                target.wl_surface().and_then(|surface| {
                    let surface_id = get_surface_id(&surface);
                    self.meta_window_state
                        .meta_popup_id_per_surface_id
                        .contains_key(&surface_id)
                        .then_some(PopupPointerGrab { surface_id })
                })
            });
        }
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
            self.popup_pointer_grab = None;
            self.end_floating_move();
            self.end_floating_resize();
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
        // Client apps get the wheel factor too (see
        // `scale_client_wheel_frame`). The unscaled `frame` is kept for Flutter
        // below.
        let client_frame = scale_client_wheel_frame(frame, self.wheel_scroll_factor);
        if !self.is_locked() {
            pointer.axis(self, client_frame);
            self.register_frame();
        }

        // Gaming mode already delivered the axis to the focused client; keep it
        // out of Flutter, like motion and buttons.
        if self.gaming_input_active() {
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
            let Some(scale) = self.scale_for_view(view_id) else {
                debug!(view_id, "dropping wheel scroll: no output owns view");
                return;
            };
            // Flutter receives physical pixels and scales them down itself, so
            // the wheel detents are converted to physical pixels here: one
            // detent is `DEFAULT_WHEEL_SCROLL_PIXELS_PER_DETENT` logical pixels
            // scaled by `wheelScrollFactor`, i.e. that many physical pixels at
            // `scale`.
            let scroll_factor = self.wheel_scroll_factor;
            let detents_x = wheel_detents(frame.axis.0, frame.v120.map(|(x, _)| x as f64));
            let detents_y = wheel_detents(frame.axis.1, frame.v120.map(|(_, y)| y as f64));
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
                    x: pointer_location.x * scale,
                    y: pointer_location.y * scale,
                    device: device_id,
                    signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindScroll,
                    scroll_delta_x: wheel_physical_pixels(detents_x, scroll_factor, scale),
                    scroll_delta_y: wheel_physical_pixels(detents_y, scroll_factor, scale),
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
                    0.,
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

    /// Shifts the stored pointer origin for a surface.
    ///
    /// Used when an override-redirect popup moves itself: its Flutter render
    /// origin moves by the same delta as the native popup, and the client uses
    /// pointer-relative coordinates to decide its next position. A stale origin
    /// there feeds the movement back into the popup and makes it accelerate.
    pub(crate) fn translate_pointer_focus_offset_for_surface(
        &mut self,
        surface_id: u64,
        dx: f64,
        dy: f64,
    ) {
        if dx == 0.0 && dy == 0.0 {
            return;
        }
        let Some(surface) = self.surfaces.get(&surface_id) else {
            return;
        };
        let Some((target, offset)) = self.pointer_focus.as_ref() else {
            return;
        };
        if target.wl_surface().as_deref() != Some(surface) {
            return;
        }
        let target = target.clone();
        self.pointer_focus = Some((target, Point::from((offset.x + dx, offset.y + dy))));
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
        let focus = self.client_pointer_focus();
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
        // While a game owns the pointer it stays on the game's output: letting
        // it cross to another monitor would re-show the cursor there and hand
        // the other desktop a stray pointer.
        let bounds = self.gaming_output_bounds().or_else(|| self.output_bounds());
        match bounds {
            Some(bounds) => clamp_to_bounds(pos, bounds),
            None => pos,
        }
    }

    /// Geometry of the output the active game owns, if any.
    fn gaming_output_bounds(&self) -> Option<Rectangle<i32, Logical>> {
        let meta_window_id = self.meta_window_state.meta_window_in_gaming_mode.as_ref()?;
        let meta_window = self.meta_window_state.meta_windows.get(meta_window_id)?;
        let output = meta_window
            .current_output
            .as_deref()
            .and_then(|name| self.space.outputs().find(|output| output.name() == name))?;
        self.space.output_geometry(output)
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
        let Some(view_scale) = self.scale_for_view(view_id) else {
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
        // libinput reports touchpad and pinch deltas in logical units (the same
        // space as pointer motion). Flutter divides the pan/zoom payload by the
        // device pixel ratio, so it has to be turned into physical pixels here,
        // exactly like the pointer position.
        self.flutter_engine()
            .send_pointer_event(FlutterPointerEvent {
                struct_size: size_of::<FlutterPointerEvent>(),
                phase,
                timestamp: FlutterEngine::<BackendData>::current_time_us() as usize,
                x: location.x * view_scale,
                y: location.y * view_scale,
                device: device_id,
                signal_kind: FlutterPointerSignalKind_kFlutterPointerSignalKindNone,
                scroll_delta_x: 0.0,
                scroll_delta_y: 0.0,
                device_kind: FlutterPointerDeviceKind_kFlutterPointerDeviceKindTrackpad,
                buttons: 0,
                pan_x: pan_x * view_scale,
                pan_y: pan_y * view_scale,
                // The Flutter pan/zoom `scale` is a gesture scale (1.0 means no
                // scaling). The output scale must not be used here: Flutter
                // would read it as a pinch. The shell does not currently track
                // a trackpad pinch scale, so the neutral value is sent.
                scale: 1.0,
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

    #[test]
    fn wheel_detents_prefer_the_v120_value() {
        // A regular 15 degree wheel sends 15 degrees / 120 v120 per detent.
        assert_eq!(wheel_detents(15.0, Some(120.0)), 1.0);
        // A 20 degree wheel turns 20 degrees per detent but is still 120 v120.
        assert_eq!(wheel_detents(20.0, Some(120.0)), 1.0);
        // A high-resolution wheel sends fractions of a detent.
        assert_eq!(wheel_detents(5.0, Some(40.0)), 40.0 / 120.0);
    }

    #[test]
    fn wheel_detents_fall_back_to_degrees() {
        assert_eq!(wheel_detents(15.0, None), 1.0);
        assert_eq!(wheel_detents(30.0, None), 2.0);
        // A stop event carries neither angle nor v120 movement.
        assert_eq!(wheel_detents(0.0, Some(0.0)), 0.0);
    }

    #[test]
    fn wheel_step_scales_with_the_factor_and_output_scale() {
        // Flutter divides the physical delta by the device pixel ratio, so
        // scaling here keeps the logical distance identical on every output.
        // 53 is the shipped step at factor 1.0; a factor scales it.
        assert_eq!(wheel_physical_pixels(1.0, 1.0, 1.0), 53.0);
        assert_eq!(wheel_physical_pixels(1.0, 1.0, 2.0) / 2.0, 53.0);
        assert_eq!(wheel_physical_pixels(1.0, 2.0, 1.0), 106.0);
    }

    #[test]
    fn scale_client_wheel_frame_scales_the_wheel_axis_and_v120() {
        let frame = AxisFrame::new(0)
            .source(AxisSource::Wheel)
            .value(Axis::Vertical, 15.0)
            .v120(Axis::Vertical, 120);

        let scaled = scale_client_wheel_frame(frame, 2.0);

        assert_eq!(scaled.axis.1, 30.0);
        assert_eq!(scaled.v120, Some((0, 240)));
    }

    #[test]
    fn scale_client_wheel_frame_leaves_other_sources_alone() {
        let frame = AxisFrame::new(0)
            .source(AxisSource::Finger)
            .value(Axis::Vertical, 15.0);

        let scaled = scale_client_wheel_frame(frame, 2.0);

        assert_eq!(scaled.axis.1, 15.0);
    }
}
