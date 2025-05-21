use std::cell::RefCell;

use smithay::{
    desktop::{space::SpaceElement, WindowSurface},
    input::{
        pointer::{
            AxisFrame, ButtonEvent, GestureHoldBeginEvent, GestureHoldEndEvent,
            GesturePinchBeginEvent, GesturePinchEndEvent, GesturePinchUpdateEvent,
            GestureSwipeBeginEvent, GestureSwipeEndEvent, GestureSwipeUpdateEvent,
            GrabStartData as PointerGrabStartData, MotionEvent, PointerGrab, PointerInnerHandle,
            RelativeMotionEvent,
        },
        touch::{GrabStartData as TouchGrabStartData, TouchGrab},
    },
    reexports::wayland_protocols::xdg::shell::server::xdg_toplevel,
    utils::{IsAlive, Logical, Point, Serial, Size},
    wayland::{compositor::with_states, shell::xdg::SurfaceCachedState},
};
use smithay::{utils::Rectangle, xwayland::xwm::ResizeEdge as X11ResizeEdge};

bitflags::bitflags! {
    #[derive(Clone, Copy, Debug, PartialEq, Eq, Hash,)]
    pub struct MetaResizeEdge: u32 {
        const NONE = 0;
        const TOP = 1;
        const BOTTOM = 2;
        const LEFT = 4;
        const TOP_LEFT = 5;
        const BOTTOM_LEFT = 6;
        const RIGHT = 8;
        const TOP_RIGHT = 9;
        const BOTTOM_RIGHT = 10;
    }
}

impl From<xdg_toplevel::ResizeEdge> for MetaResizeEdge {
    #[inline]
    fn from(x: xdg_toplevel::ResizeEdge) -> Self {
        Self::from_bits(x as u32).unwrap()
    }
}

impl From<MetaResizeEdge> for xdg_toplevel::ResizeEdge {
    #[inline]
    fn from(x: MetaResizeEdge) -> Self {
        Self::try_from(x.bits()).unwrap()
    }
}

impl From<X11ResizeEdge> for MetaResizeEdge {
    #[inline]
    fn from(edge: X11ResizeEdge) -> Self {
        match edge {
            X11ResizeEdge::Bottom => MetaResizeEdge::BOTTOM,
            X11ResizeEdge::BottomLeft => MetaResizeEdge::BOTTOM_LEFT,
            X11ResizeEdge::BottomRight => MetaResizeEdge::BOTTOM_RIGHT,
            X11ResizeEdge::Left => MetaResizeEdge::LEFT,
            X11ResizeEdge::Right => MetaResizeEdge::RIGHT,
            X11ResizeEdge::Top => MetaResizeEdge::TOP,
            X11ResizeEdge::TopLeft => MetaResizeEdge::TOP_LEFT,
            X11ResizeEdge::TopRight => MetaResizeEdge::TOP_RIGHT,
        }
    }
}
