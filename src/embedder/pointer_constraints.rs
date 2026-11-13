//! `zwp_pointer_constraints_v1`: pointer lock and confinement.
//!
//! Games lock the pointer to rotate a camera from relative motion
//! (`zwp_relative_pointer_v1`) and confine it to keep it inside their window.
//! Xwayland uses the same protocols to emulate X11 pointer grabs and warps.
//!
//! A constraint is active only while its surface has the pointer focus and
//! its client has the keyboard focus: a window in the background cannot trap
//! the pointer, and anything that takes the keyboard focus away (a shell
//! shortcut, the launcher, the lock screen) releases it.

use smithay::backend::renderer::utils::with_renderer_surface_state;
use smithay::input::pointer::{MotionEvent, PointerHandle, RelativeMotionEvent};
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::reexports::wayland_server::Resource;
use smithay::utils::{Logical, Point, Size, SERIAL_COUNTER};
use smithay::wayland::compositor::RegionAttributes;
use smithay::wayland::pointer_constraints::{
    with_pointer_constraint, PointerConstraint, PointerConstraintsHandler,
};
use smithay::wayland::seat::WaylandFocus;

use crate::backend::Backend;
use crate::state::State;

/// The active constraint that applies to the next pointer motion.
pub enum ActivePointerConstraint {
    /// The pointer does not move; the client only receives relative motion.
    Locked,
    /// The pointer moves, but stays inside the surface and its region.
    Confined {
        /// Global position of the surface origin.
        origin: Point<f64, Logical>,
        /// Size of the surface, when it has a buffer.
        size: Option<Size<i32, Logical>>,
        region: Option<RegionAttributes>,
    },
}

/// Moves the pointer from `current` towards `target` without leaving the
/// confinement area: the surface at `origin` (when its `size` is known) and,
/// within it, `region` in surface-local coordinates.
///
/// The target is first clamped to the surface, so a fast motion stops at its
/// edge instead of short of it. An axis whose motion would leave the region is
/// dropped, so the pointer slides along a region edge.
pub fn confine_motion(
    current: Point<f64, Logical>,
    target: Point<f64, Logical>,
    origin: Point<f64, Logical>,
    size: Option<Size<i32, Logical>>,
    region: Option<&RegionAttributes>,
) -> Point<f64, Logical> {
    let mut target = target;
    if let Some(size) = size.filter(|size| size.w > 0 && size.h > 0) {
        // Surface-local pixels are `[0, size)`: stay within the last one.
        let max_x = origin.x + (size.w as f64 - 1.0);
        let max_y = origin.y + (size.h as f64 - 1.0);
        target = (
            target.x.clamp(origin.x, max_x),
            target.y.clamp(origin.y, max_y),
        )
            .into();
    }
    let Some(region) = region else {
        return target;
    };
    let inside = |p: Point<f64, Logical>| region.contains((p - origin).to_i32_round());
    if inside(target) {
        return target;
    }
    let horizontal = Point::from((target.x, current.y));
    if inside(horizontal) {
        return horizontal;
    }
    let vertical = Point::from((current.x, target.y));
    if inside(vertical) {
        return vertical;
    }
    current
}

impl<BackendData: Backend + 'static> State<BackendData> {
    /// The pointer-focused surface and the global position of its origin.
    fn constraint_focus(&self) -> Option<(WlSurface, Point<f64, Logical>)> {
        let (target, origin) = self.client_pointer_focus()?;
        Some((target.wl_surface()?.into_owned(), origin))
    }

    /// The constraint that the focused surface holds active, if any.
    pub fn active_pointer_constraint(&self) -> Option<ActivePointerConstraint> {
        let (surface, origin) = self.constraint_focus()?;
        let size = with_renderer_surface_state(&surface, |state| state.surface_size()).flatten();
        with_pointer_constraint(&surface, &self.pointer, |constraint| {
            let constraint = constraint.filter(|constraint| constraint.is_active())?;
            Some(match &*constraint {
                PointerConstraint::Locked(_) => ActivePointerConstraint::Locked,
                PointerConstraint::Confined(confined) => ActivePointerConstraint::Confined {
                    origin,
                    size,
                    region: confined.region().cloned(),
                },
            })
        })
    }

    /// Applies an active lock or confinement to a pointer motion.
    ///
    /// Sends the relative motion to the focused client, then returns where the
    /// pointer may move, or `None` when it is locked and must stay put.
    pub fn constrain_pointer_motion(
        &mut self,
        current: Point<f64, Logical>,
        target: Point<f64, Logical>,
        relative: Option<RelativeMotionEvent>,
    ) -> Option<Point<f64, Logical>> {
        let constraint = self.active_pointer_constraint();
        if let Some(event) = relative {
            let pointer = self.pointer.clone();
            pointer.relative_motion(self, self.client_pointer_focus(), &event);
        }
        match constraint {
            None => Some(target),
            Some(ActivePointerConstraint::Locked) => None,
            Some(ActivePointerConstraint::Confined {
                origin,
                size,
                region,
            }) => Some(confine_motion(
                current,
                target,
                origin,
                size,
                region.as_ref(),
            )),
        }
    }

    /// Activates or deactivates the focused surface's constraint after the
    /// pointer or the keyboard focus changed.
    ///
    /// `keyboard_focus` is the surface holding the keyboard focus; pass
    /// [`State::keyboard_focus_surface`] unless the keyboard is being updated.
    pub fn update_pointer_constraint(&mut self, keyboard_focus: Option<WlSurface>) {
        let pointer = self.pointer.clone();
        let location = pointer.current_location();
        let Some((surface, origin)) = self.constraint_focus() else {
            // Smithay deactivates a constraint when its surface loses the
            // pointer focus.
            return;
        };
        let keyboard_client = keyboard_focus.and_then(|surface| surface.client());
        let allowed = keyboard_client.is_some() && keyboard_client == surface.client();
        with_pointer_constraint(&surface, &pointer, |constraint| {
            let Some(constraint) = constraint else {
                return;
            };
            if !allowed {
                if constraint.is_active() {
                    constraint.deactivate(self, &surface, &pointer);
                }
                return;
            }
            if !constraint.is_active() {
                let point = (location - origin).to_i32_round();
                if constraint
                    .region()
                    .is_none_or(|region| region.contains(point))
                {
                    constraint.activate();
                }
            }
        });
    }

    /// The surface holding the keyboard focus.
    pub fn keyboard_focus_surface(&self) -> Option<WlSurface> {
        self.keyboard
            .current_focus()
            .and_then(|focus| focus.wl_surface().map(|surface| surface.into_owned()))
    }

    /// Moves the pointer to the position hint a locked client committed, once
    /// its lock is released.
    ///
    /// Runs on idle: Smithay reports the release with the pointer and the
    /// surface's constraint data locked.
    fn warp_to_cursor_position_hint(&mut self, surface: WlSurface, hint: Point<f64, Logical>) {
        self.loop_handle.insert_idle(move |data| {
            let Some(focus) = data.client_pointer_focus() else {
                return;
            };
            if focus.0.wl_surface().as_deref() != Some(&surface) {
                return;
            }
            let location = focus.1 + hint;
            let pointer = data.pointer.clone();
            pointer.motion(
                data,
                Some(focus),
                &MotionEvent {
                    location,
                    serial: SERIAL_COUNTER.next_serial(),
                    time: data.frame_timestamp_millis(),
                },
            );
            pointer.frame(data);
            data.request_render();
        });
    }
}

impl<BackendData: Backend + 'static> PointerConstraintsHandler for State<BackendData> {
    fn new_constraint(&mut self, _surface: &WlSurface, _pointer: &PointerHandle<Self>) {
        let keyboard_focus = self.keyboard_focus_surface();
        self.update_pointer_constraint(keyboard_focus);
    }

    fn remove_constraint(
        &mut self,
        surface: &WlSurface,
        _pointer: &PointerHandle<Self>,
        _constraint: Option<&PointerConstraint>,
    ) {
        let Some((hint_surface, hint)) = self.cursor_position_hint.take() else {
            return;
        };
        if &hint_surface == surface {
            self.warp_to_cursor_position_hint(hint_surface, hint);
        }
    }

    fn cursor_position_hint(
        &mut self,
        surface: &WlSurface,
        pointer: &PointerHandle<Self>,
        location: Point<f64, Logical>,
    ) {
        if with_pointer_constraint(surface, pointer, |constraint| {
            constraint.is_some_and(|constraint| constraint.is_active())
        }) {
            self.cursor_position_hint = Some((surface.clone(), location));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use smithay::utils::Rectangle;
    use smithay::wayland::compositor::RectangleKind;

    fn p(x: f64, y: f64) -> Point<f64, Logical> {
        (x, y).into()
    }

    fn region(rects: &[(i32, i32, i32, i32)]) -> RegionAttributes {
        RegionAttributes {
            rects: rects
                .iter()
                .map(|&(x, y, w, h)| {
                    (
                        RectangleKind::Add,
                        Rectangle::new((x, y).into(), (w, h).into()),
                    )
                })
                .collect(),
        }
    }

    #[test]
    fn confinement_clamps_to_the_surface() {
        let origin = p(100.0, 50.0);
        let size = Some((200, 100).into());
        assert_eq!(
            confine_motion(p(150.0, 80.0), p(400.0, 0.0), origin, size, None),
            p(299.0, 50.0)
        );
        assert_eq!(
            confine_motion(p(150.0, 80.0), p(160.0, 90.0), origin, size, None),
            p(160.0, 90.0)
        );
    }

    #[test]
    fn confinement_slides_along_a_region_edge() {
        let origin = p(0.0, 0.0);
        let size = Some((100, 100).into());
        let region = region(&[(10, 10, 20, 20)]);
        // Moving right and down out of the region keeps the vertical motion.
        assert_eq!(
            confine_motion(p(25.0, 15.0), p(40.0, 20.0), origin, size, Some(&region)),
            p(25.0, 20.0)
        );
        // Moving out on both axes keeps the pointer where it was.
        assert_eq!(
            confine_motion(p(25.0, 25.0), p(40.0, 40.0), origin, size, Some(&region)),
            p(25.0, 25.0)
        );
    }

    #[test]
    fn confinement_without_a_buffer_only_follows_the_region() {
        let region = region(&[(0, 0, 50, 50)]);
        assert_eq!(
            confine_motion(
                p(10.0, 10.0),
                p(20.0, 30.0),
                p(0.0, 0.0),
                None,
                Some(&region)
            ),
            p(20.0, 30.0)
        );
    }
}
