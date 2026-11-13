//! Keeps the live output layout anchored at the origin.
//!
//! Stored monitor locations are absolute, so with a monitor disconnected the
//! ones left can start far from `(0, 0)` (a single monitor at `x = 2560`).
//! Xwayland's root then begins with an area no monitor covers, and X11
//! clients that assume the screen starts at the root origin misread every
//! pointer position: a Wine game clamps the cursor to its right edge.
//!
//! The live layout is therefore shifted so its bounding box starts at
//! `(0, 0)`, as the arrangement editor already does when it saves a layout.
//! The stored configuration is left untouched: `output_layout_origin` maps a
//! stored location to a live one, so reconnecting the missing monitor
//! restores the saved arrangement.

use smithay::output::Output;
use smithay::utils::{Logical, Point};
use tracing::info;

use crate::backend::Backend;
use crate::meta_window_state::meta_window::MetaWindowPatch;
use crate::state::State;

/// The shift that brings the top-left of `locations` to the origin, or `None`
/// when it is already there (or there is no output).
pub fn normalization_shift(
    locations: impl IntoIterator<Item = Point<i32, Logical>>,
) -> Option<Point<i32, Logical>> {
    let mut locations = locations.into_iter();
    let first = locations.next()?;
    let top_left = locations.fold(first, |top_left, location| {
        (top_left.x.min(location.x), top_left.y.min(location.y)).into()
    });
    (top_left != Point::from((0, 0))).then_some(top_left)
}

impl<BackendData: Backend + 'static> State<BackendData> {
    /// The live location of an output whose stored location is `stored`.
    pub fn live_output_location(&self, stored: Point<i32, Logical>) -> Point<i32, Logical> {
        stored - self.output_layout_origin
    }

    /// Shifts the live layout so its top-left is the origin, moving
    /// everything placed in global coordinates with it.
    pub(crate) fn normalize_output_layout(&mut self) {
        let outputs: Vec<Output> = self.space.outputs().cloned().collect();
        let Some(shift) = normalization_shift(outputs.iter().map(Output::current_location)) else {
            return;
        };
        for output in &outputs {
            let location = output.current_location() - shift;
            output.change_current_state(None, None, None, Some(location));
            self.space.map_output(output, location);
        }
        self.output_layout_origin += shift;
        info!(
            target: "veshell::geometry",
            ?shift,
            origin = ?self.output_layout_origin,
            "Normalized the output layout to the origin"
        );

        // The pointer stays over the same spot of the same monitor.
        let shift_f64 = shift.to_f64();
        let pointer = self.pointer.clone();
        pointer.set_location(pointer.current_location() - shift_f64);
        if let Some((_, origin)) = self.pointer_focus.as_mut() {
            *origin -= shift_f64;
        }

        self.shift_windows_with_layout(shift);
    }

    /// Keeps windows on the same spot of their monitor after the layout moved
    /// by `-shift`: a floating window keeps its place, a tiled X11 window is
    /// re-rooted at its output's new origin (see `tiled_x11_root`).
    fn shift_windows_with_layout(&mut self, shift: Point<i32, Logical>) {
        let ids: Vec<String> = self
            .meta_window_state
            .meta_windows
            .keys()
            .cloned()
            .collect();
        for id in ids {
            let Some(meta_window) = self.meta_window_state.meta_windows.get(&id) else {
                continue;
            };
            let is_floating = meta_window.is_floating();
            let position = meta_window.position.as_ref().map(|position| position.0);
            let current_output = meta_window.current_output.clone();
            let x11_surface = self
                .surfaces
                .get(&meta_window.surface_id)
                .and_then(|surface| self.x11_surface_per_wl_surface.get(surface))
                .cloned();

            if is_floating {
                if let Some(position) = position {
                    self.patch_meta_window(
                        MetaWindowPatch::UpdatePosition {
                            id: id.clone(),
                            value: Some((position - shift).into()),
                        },
                        true,
                    );
                }
                if let Some(x11_surface) = x11_surface {
                    let mut configure = x11_surface.last_configure();
                    configure.loc -= shift;
                    let _ = x11_surface.configure(configure);
                }
            } else if let Some(x11_surface) = x11_surface {
                let root = self.tiled_x11_root(current_output.as_deref());
                let mut configure = x11_surface.last_configure();
                if configure.loc != root {
                    configure.loc = root;
                    let _ = x11_surface.configure(configure);
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn p(x: i32, y: i32) -> Point<i32, Logical> {
        (x, y).into()
    }

    #[test]
    fn a_layout_at_the_origin_is_left_alone() {
        assert_eq!(normalization_shift([p(0, 0), p(2560, 0)]), None);
        assert_eq!(normalization_shift([]), None);
    }

    #[test]
    fn a_lone_offset_monitor_moves_to_the_origin() {
        assert_eq!(normalization_shift([p(2560, 0)]), Some(p(2560, 0)));
    }

    #[test]
    fn the_shift_is_taken_per_axis() {
        // A monitor above and one to the right: the bounding box starts at
        // the leftmost x and the topmost y, which no single monitor holds.
        assert_eq!(
            normalization_shift([p(1920, 200), p(3840, -300)]),
            Some(p(1920, -300))
        );
    }
}
