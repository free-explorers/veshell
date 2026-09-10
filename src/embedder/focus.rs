use std::{borrow::Cow, sync::Arc};

use smithay::input::{
    dnd::{DndFocus, OfferData, Source},
    pointer::{
        GestureHoldBeginEvent, GestureHoldEndEvent, GesturePinchBeginEvent, GesturePinchEndEvent,
        GesturePinchUpdateEvent, GestureSwipeBeginEvent, GestureSwipeEndEvent,
        GestureSwipeUpdateEvent,
    },
    touch::{FrameMarker, TouchTarget},
};
use smithay::xwayland::X11Surface;
use smithay::xwayland::xwm::XwmOfferData;
use smithay::wayland::selection::data_device::WlOfferData;
use smithay::reexports::wayland_server::DisplayHandle;
pub use smithay::{
    backend::input::KeyState,
    desktop::PopupKind,
    input::{
        keyboard::{KeyboardTarget, KeysymHandle, ModifiersState},
        pointer::{AxisFrame, ButtonEvent, MotionEvent, PointerTarget, RelativeMotionEvent},
        Seat,
    },
    reexports::wayland_server::{backend::ObjectId, protocol::wl_surface::WlSurface},
    utils::{IsAlive, Logical, Point, Serial},
    wayland::seat::WaylandFocus,
};

use crate::backend::Backend;
use crate::state::State;

#[derive(Debug, Clone, PartialEq)]
pub enum KeyboardFocusTarget {
    WlSurface(WlSurface),
    X11Surface(X11Surface),
}
impl IsAlive for KeyboardFocusTarget {
    fn alive(&self) -> bool {
        match self {
            KeyboardFocusTarget::WlSurface(w) => w.alive(),
            KeyboardFocusTarget::X11Surface(w) => w.alive(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum PointerFocusTarget {
    WlSurface(WlSurface),
    X11Surface(X11Surface),
}

impl IsAlive for PointerFocusTarget {
    fn alive(&self) -> bool {
        match self {
            PointerFocusTarget::WlSurface(w) => w.alive(),
            PointerFocusTarget::X11Surface(w) => w.alive(),
        }
    }
}

impl<BackendData: Backend> smithay::wayland::pointer_constraints::PointerConstraintsHandler
    for State<BackendData>
{
}

pub enum PointerOfferData<S: Source> {
    Wl(WlOfferData<S>),
    X11(XwmOfferData<S>),
}

impl<S: Source> OfferData for PointerOfferData<S> {
    fn disable(&self) {
        match self { Self::Wl(v) => v.disable(), Self::X11(v) => v.disable() }
    }
    fn drop(&self) {
        match self { Self::Wl(v) => v.drop(), Self::X11(v) => v.drop() }
    }
    fn validated(&self) -> bool {
        match self { Self::Wl(v) => v.validated(), Self::X11(v) => v.validated() }
    }
}

impl<BackendData: Backend + 'static> DndFocus<State<BackendData>> for PointerFocusTarget {
    type OfferData<S: Source> = PointerOfferData<S>;

    fn enter<S: Source>(&self, data: &mut State<BackendData>, dh: &DisplayHandle,
        source: Arc<S>, seat: &Seat<State<BackendData>>, location: Point<f64, Logical>,
        serial: &Serial) -> Option<Self::OfferData<S>> {
        match self {
            Self::WlSurface(surface) => DndFocus::enter(surface, data, dh, source, seat, location, serial).map(PointerOfferData::Wl),
            Self::X11Surface(surface) => DndFocus::enter(surface, data, dh, source, seat, location, serial).map(PointerOfferData::X11),
        }
    }

    fn motion<S: Source>(&self, data: &mut State<BackendData>, offer: Option<&mut Self::OfferData<S>>,
        seat: &Seat<State<BackendData>>, location: Point<f64, Logical>, time: u32) {
        match (self, offer) {
            (Self::WlSurface(surface), Some(PointerOfferData::Wl(offer))) => DndFocus::motion(surface, data, Some(offer), seat, location, time),
            (Self::X11Surface(surface), Some(PointerOfferData::X11(offer))) => DndFocus::motion(surface, data, Some(offer), seat, location, time),
            _ => {}
        }
    }

    fn leave<S: Source>(&self, data: &mut State<BackendData>, offer: Option<&mut Self::OfferData<S>>, seat: &Seat<State<BackendData>>) {
        match (self, offer) {
            (Self::WlSurface(surface), Some(PointerOfferData::Wl(offer))) => DndFocus::leave(surface, data, Some(offer), seat),
            (Self::X11Surface(surface), Some(PointerOfferData::X11(offer))) => DndFocus::leave(surface, data, Some(offer), seat),
            _ => {}
        }
    }

    fn drop<S: Source>(&self, data: &mut State<BackendData>, offer: Option<&mut Self::OfferData<S>>, seat: &Seat<State<BackendData>>) {
        match (self, offer) {
            (Self::WlSurface(surface), Some(PointerOfferData::Wl(offer))) => DndFocus::drop(surface, data, Some(offer), seat),
            (Self::X11Surface(surface), Some(PointerOfferData::X11(offer))) => DndFocus::drop(surface, data, Some(offer), seat),
            _ => {}
        }
    }
}

impl From<PointerFocusTarget> for WlSurface {
    fn from(target: PointerFocusTarget) -> Self {
        target.wl_surface().unwrap().into_owned()
    }
}

impl<BackendData: Backend> PointerTarget<State<BackendData>> for PointerFocusTarget {
    fn enter(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &MotionEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => PointerTarget::enter(w, seat, data, event),
            PointerFocusTarget::X11Surface(w) => PointerTarget::enter(w, seat, data, event),
        }
    }
    fn motion(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &MotionEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => PointerTarget::motion(w, seat, data, event),
            PointerFocusTarget::X11Surface(w) => PointerTarget::motion(w, seat, data, event),
        }
    }
    fn relative_motion(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &RelativeMotionEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => {
                PointerTarget::relative_motion(w, seat, data, event)
            }
            PointerFocusTarget::X11Surface(w) => {
                PointerTarget::relative_motion(w, seat, data, event)
            }
        }
    }
    fn button(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &ButtonEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => PointerTarget::button(w, seat, data, event),
            PointerFocusTarget::X11Surface(w) => PointerTarget::button(w, seat, data, event),
        }
    }
    fn axis(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        frame: AxisFrame,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => PointerTarget::axis(w, seat, data, frame),
            PointerFocusTarget::X11Surface(w) => PointerTarget::axis(w, seat, data, frame),
        }
    }
    fn frame(&self, seat: &Seat<State<BackendData>>, data: &mut State<BackendData>) {
        match self {
            PointerFocusTarget::WlSurface(w) => PointerTarget::frame(w, seat, data),
            PointerFocusTarget::X11Surface(w) => PointerTarget::frame(w, seat, data),
        }
    }
    fn leave(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        serial: Serial,
        time: u32,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => PointerTarget::leave(w, seat, data, serial, time),
            PointerFocusTarget::X11Surface(w) => PointerTarget::leave(w, seat, data, serial, time),
        }
    }
    fn gesture_swipe_begin(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &GestureSwipeBeginEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => {
                PointerTarget::gesture_swipe_begin(w, seat, data, event)
            }
            PointerFocusTarget::X11Surface(w) => {
                PointerTarget::gesture_swipe_begin(w, seat, data, event)
            }
        }
    }
    fn gesture_swipe_update(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &GestureSwipeUpdateEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => {
                PointerTarget::gesture_swipe_update(w, seat, data, event)
            }
            PointerFocusTarget::X11Surface(w) => {
                PointerTarget::gesture_swipe_update(w, seat, data, event)
            }
        }
    }
    fn gesture_swipe_end(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &GestureSwipeEndEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => {
                PointerTarget::gesture_swipe_end(w, seat, data, event)
            }
            PointerFocusTarget::X11Surface(w) => {
                PointerTarget::gesture_swipe_end(w, seat, data, event)
            }
        }
    }
    fn gesture_pinch_begin(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &GesturePinchBeginEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => {
                PointerTarget::gesture_pinch_begin(w, seat, data, event)
            }
            PointerFocusTarget::X11Surface(w) => {
                PointerTarget::gesture_pinch_begin(w, seat, data, event)
            }
        }
    }
    fn gesture_pinch_update(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &GesturePinchUpdateEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => {
                PointerTarget::gesture_pinch_update(w, seat, data, event)
            }
            PointerFocusTarget::X11Surface(w) => {
                PointerTarget::gesture_pinch_update(w, seat, data, event)
            }
        }
    }
    fn gesture_pinch_end(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &GesturePinchEndEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => {
                PointerTarget::gesture_pinch_end(w, seat, data, event)
            }
            PointerFocusTarget::X11Surface(w) => {
                PointerTarget::gesture_pinch_end(w, seat, data, event)
            }
        }
    }
    fn gesture_hold_begin(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &GestureHoldBeginEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => {
                PointerTarget::gesture_hold_begin(w, seat, data, event)
            }
            PointerFocusTarget::X11Surface(w) => {
                PointerTarget::gesture_hold_begin(w, seat, data, event)
            }
        }
    }
    fn gesture_hold_end(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &GestureHoldEndEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => {
                PointerTarget::gesture_hold_end(w, seat, data, event)
            }
            PointerFocusTarget::X11Surface(w) => {
                PointerTarget::gesture_hold_end(w, seat, data, event)
            }
        }
    }
}

impl<BackendData: Backend> KeyboardTarget<State<BackendData>> for KeyboardFocusTarget {
    fn enter(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        keys: Vec<KeysymHandle<'_>>,
        serial: Serial,
    ) {
        match self {
            KeyboardFocusTarget::WlSurface(s) => KeyboardTarget::enter(s, seat, data, keys, serial),
            KeyboardFocusTarget::X11Surface(s) => {
                KeyboardTarget::enter(s, seat, data, keys, serial)
            }
        }
    }
    fn leave(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        serial: Serial,
    ) {
        match self {
            KeyboardFocusTarget::WlSurface(s) => KeyboardTarget::leave(s, seat, data, serial),
            KeyboardFocusTarget::X11Surface(s) => KeyboardTarget::leave(s, seat, data, serial),
        }
    }
    fn key(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        key: KeysymHandle<'_>,
        state: KeyState,
        serial: Serial,
        time: u32,
    ) {
        match self {
            KeyboardFocusTarget::WlSurface(s) => {
                KeyboardTarget::key(s, seat, data, key, state, serial, time)
            }
            KeyboardFocusTarget::X11Surface(s) => {
                KeyboardTarget::key(s, seat, data, key, state, serial, time)
            }
        }
    }
    fn modifiers(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        modifiers: ModifiersState,
        serial: Serial,
    ) {
        match self {
            KeyboardFocusTarget::WlSurface(s) => {
                KeyboardTarget::modifiers(s, seat, data, modifiers, serial)
            }
            KeyboardFocusTarget::X11Surface(s) => {
                KeyboardTarget::modifiers(s, seat, data, modifiers, serial)
            }
        }
    }
}

impl<BackendData: Backend> TouchTarget<State<BackendData>> for PointerFocusTarget {
    fn down(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &smithay::input::touch::DownEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => TouchTarget::down(w, seat, data, event),
            PointerFocusTarget::X11Surface(w) => TouchTarget::down(w, seat, data, event),
        }
    }

    fn up(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &smithay::input::touch::UpEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => TouchTarget::up(w, seat, data, event),
            PointerFocusTarget::X11Surface(w) => TouchTarget::up(w, seat, data, event),
        }
    }

    fn motion(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &smithay::input::touch::MotionEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => TouchTarget::motion(w, seat, data, event),
            PointerFocusTarget::X11Surface(w) => TouchTarget::motion(w, seat, data, event),
        }
    }

    fn frame(&self, seat: &Seat<State<BackendData>>, data: &mut State<BackendData>, marker: FrameMarker) {
        match self {
            PointerFocusTarget::WlSurface(w) => TouchTarget::frame(w, seat, data, marker),
            PointerFocusTarget::X11Surface(w) => TouchTarget::frame(w, seat, data, marker),
        }
    }

    fn cancel(&self, seat: &Seat<State<BackendData>>, data: &mut State<BackendData>, marker: FrameMarker) {
        match self {
            PointerFocusTarget::WlSurface(w) => TouchTarget::cancel(w, seat, data, marker),
            PointerFocusTarget::X11Surface(w) => TouchTarget::cancel(w, seat, data, marker),
        }
    }

    fn shape(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &smithay::input::touch::ShapeEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => TouchTarget::shape(w, seat, data, event),
            PointerFocusTarget::X11Surface(w) => TouchTarget::shape(w, seat, data, event),
        }
    }

    fn orientation(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
        event: &smithay::input::touch::OrientationEvent,
    ) {
        match self {
            PointerFocusTarget::WlSurface(w) => TouchTarget::orientation(w, seat, data, event),
            PointerFocusTarget::X11Surface(w) => {
                TouchTarget::orientation(w, seat, data, event)
            }
        }
    }

    fn last_frame(
        &self,
        seat: &Seat<State<BackendData>>,
        data: &mut State<BackendData>,
    ) -> Option<FrameMarker> {
        match self {
            PointerFocusTarget::WlSurface(w) => TouchTarget::last_frame(w, seat, data),
            PointerFocusTarget::X11Surface(w) => TouchTarget::last_frame(w, seat, data),
        }
    }
}

impl WaylandFocus for PointerFocusTarget {
    fn wl_surface(&self) -> Option<Cow<'_, WlSurface>> {
        match self {
            PointerFocusTarget::WlSurface(w) => w.wl_surface(),
            PointerFocusTarget::X11Surface(w) => w.wl_surface().map(Cow::Owned),
        }
    }
    fn same_client_as(&self, object_id: &ObjectId) -> bool {
        match self {
            PointerFocusTarget::WlSurface(w) => w.same_client_as(object_id),
            PointerFocusTarget::X11Surface(w) => w.same_client_as(object_id),
        }
    }
}

impl WaylandFocus for KeyboardFocusTarget {
    fn wl_surface(&self) -> Option<Cow<'_, WlSurface>> {
        match self {
            KeyboardFocusTarget::WlSurface(s) => s.wl_surface(),
            KeyboardFocusTarget::X11Surface(s) => s.wl_surface().map(Cow::Owned),
        }
    }
}

impl From<WlSurface> for PointerFocusTarget {
    fn from(value: WlSurface) -> Self {
        PointerFocusTarget::WlSurface(value)
    }
}

impl From<&WlSurface> for PointerFocusTarget {
    fn from(value: &WlSurface) -> Self {
        PointerFocusTarget::from(value.clone())
    }
}

impl From<PopupKind> for PointerFocusTarget {
    fn from(value: PopupKind) -> Self {
        PointerFocusTarget::from(value.wl_surface())
    }
}

impl From<X11Surface> for PointerFocusTarget {
    fn from(value: X11Surface) -> Self {
        PointerFocusTarget::X11Surface(value)
    }
}

impl From<&X11Surface> for PointerFocusTarget {
    fn from(value: &X11Surface) -> Self {
        PointerFocusTarget::from(value.clone())
    }
}

impl From<KeyboardFocusTarget> for PointerFocusTarget {
    fn from(value: KeyboardFocusTarget) -> Self {
        match value {
            KeyboardFocusTarget::WlSurface(s) => PointerFocusTarget::from(s),
            KeyboardFocusTarget::X11Surface(s) => PointerFocusTarget::from(s),
        }
    }
}
