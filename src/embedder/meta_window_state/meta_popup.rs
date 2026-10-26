use serde::{Deserialize, Serialize};
use serde_json::json;
use smithay::{
    utils::{Logical, Point, Rectangle, Size},
    wayland::{compositor::with_states, fractional_scale::with_fractional_scale},
    xwayland::XWaylandClientData,
};

use crate::{
    backend::Backend,
    flutter_engine::wayland_messages::{MyPoint, MyRectangle},
    state::State,
};

/// The tile-content placement of a popup's client surface.
///
/// `origin` is the popup box origin relative to the owning tile's content
/// origin; `geometry_offset` is the surface-local offset inside the popup
/// buffer. This mirrors `WindowPlacement`, with the tile as the coordinate
/// anchor instead of the compositor root.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PopupPlacement {
    pub origin: Point<i32, Logical>,
    pub geometry_offset: Point<i32, Logical>,
}

impl PopupPlacement {
    /// The origin pointer coordinates are relative to.
    pub fn surface_origin(&self) -> Point<f64, Logical> {
        Point::from((
            f64::from(self.origin.x - self.geometry_offset.x),
            f64::from(self.origin.y - self.geometry_offset.y),
        ))
    }
}

#[derive(Serialize, Deserialize, Clone, Copy, Debug, Default, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum MetaPopupCategory {
    /// A regular client popup that should be rendered as UI.
    #[default]
    Popup,
    /// A menu, dropdown, combo or other interactive menu popup.
    Menu,
    /// A tooltip-like popup. Some X11 clients use this type for floating
    /// panels, so it is not hidden by default.
    Tooltip,
    /// A non-visible or non-interactive backing window owned by the client.
    /// The shell keeps it in the model for focus/bookkeeping but does not
    /// render it as a popup surface.
    Helper,
}

#[derive(Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct MetaPopup {
    pub id: String,
    pub parent: String,
    pub category: MetaPopupCategory,
    /// Position of the popup surface relative to the owning tile's content
    /// origin.
    ///
    /// X11 reports override-redirect popups at the root and Wayland xdg
    /// popups relative to the parent; both are normalized to tile-content
    /// coordinates when they enter the model. The tile popup host renders
    /// directly in this space, so moving a parent window inside the tile does
    /// not move an X11 popup.
    pub position: MyPoint<i32, Logical>,
    pub geometry: Option<MyRectangle<i32, Logical>>,
    /// The X11 root position of an override-redirect popup. The shared model
    /// stores tile-relative placement, but moving the owning tile must also
    /// move the independent native X11 window by the same delta.
    #[serde(skip)]
    pub native_root: Option<MyPoint<i32, Logical>>,
    /// The Wayland popup's parent-box-relative protocol position. Kept so a
    /// popup opened before the parent's tile/render origin is known can be
    /// renormalized once that origin arrives.
    #[serde(skip)]
    pub parent_relative: Option<MyPoint<i32, Logical>>,
    pub surface_id: u64,
    pub scale_ratio: f64,
}

impl MetaPopup {
    /// The tile-content placement represented by the current model.
    pub fn placement(&self) -> PopupPlacement {
        let geometry_offset = self
            .geometry
            .as_ref()
            .map(|geometry| geometry.0.loc)
            .unwrap_or_else(|| Point::from((0, 0)));
        PopupPlacement {
            origin: self.position.0,
            geometry_offset,
        }
    }
}

#[derive(Serialize, Deserialize, Clone)]
#[serde(tag = "type")]
pub enum MetaPopupPatch {
    UpdatePosition {
        id: String,
        value: MyPoint<i32, Logical>,
    },
    UpdateGeometry {
        id: String,
        value: Option<MyRectangle<i32, Logical>>,
    },
}

impl<BackendData: Backend + 'static> State<BackendData> {
    pub fn create_meta_popup(&mut self, meta_popup: MetaPopup) -> MetaPopup {
        tracing::info!(
            target: "veshell::geometry",
            popup_id = %meta_popup.id,
            surface_id = meta_popup.surface_id,
            parent = %meta_popup.parent,
            category = ?meta_popup.category,
            position = ?meta_popup.position,
            geometry = ?meta_popup.geometry,
            "Publishing popup geometry to Flutter"
        );
        self.meta_window_state
            .meta_popups
            .insert(meta_popup.id.clone(), meta_popup.clone());
        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "meta_popup_created",
            Some(Box::new(json!(meta_popup))),
            None,
        );
        meta_popup
    }

    pub fn patch_meta_popup(&mut self, patch: MetaPopupPatch, propagate: bool) {
        match patch.clone() {
            MetaPopupPatch::UpdatePosition { id, value } => {
                if let Some(meta_popup) = self.meta_window_state.meta_popups.get_mut(&id) {
                    tracing::info!(
                        target: "veshell::geometry",
                        popup_id = %id,
                        position = ?value,
                        "Updating popup position for Flutter"
                    );
                    meta_popup.position = value.clone();
                }
            }
            MetaPopupPatch::UpdateGeometry { id, value } => {
                if let Some(meta_popup) = self.meta_window_state.meta_popups.get_mut(&id) {
                    meta_popup.geometry = value.clone();
                }
            }
        }
        if propagate {
            let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
            platform_method_channel.invoke_method(
                "meta_popup_patch",
                Some(Box::new(json!(patch))),
                None,
            );
        }
    }
    /// Translate the Wayland popups owned by a root window after the parent
    /// itself moves inside its tile.
    ///
    /// X11 override-redirect popups are deliberately excluded: they are
    /// independent native windows and only a native configure event may move
    /// them. Wayland xdg popups, by contrast, follow their parent.
    pub fn translate_wayland_popups_for_root(
        &mut self,
        parent_meta_window_id: &str,
        dx: i32,
        dy: i32,
    ) {
        if dx == 0 && dy == 0 {
            return;
        }
        let popups: Vec<(String, MyPoint<i32, Logical>)> = self
            .meta_window_state
            .meta_popups
            .values()
            .filter(|popup| popup.parent == parent_meta_window_id)
            .filter(|popup| self.xdg_popups.contains_key(&popup.surface_id))
            .map(|popup| {
                (
                    popup.id.clone(),
                    MyPoint::from(Point::from((
                        popup.position.0.x + dx,
                        popup.position.0.y + dy,
                    ))),
                )
            })
            .collect();
        for (popup_id, position) in popups {
            self.patch_meta_popup(
                MetaPopupPatch::UpdatePosition {
                    id: popup_id,
                    value: position,
                },
                true,
            );
        }
    }

    /// Keep a Wayland popup's client surface inside its tile.
    ///
    /// The protocol positioner is advisory: clients can request a menu below
    /// the tile edge without slide/flip adjustment. The tile host clips such a
    /// popup away entirely, so clamp the resolved tile-relative position after
    /// the popup geometry is known.
    pub fn clamp_meta_popup_to_tile(&mut self, meta_popup_id: &str) {
        let Some(popup) = self
            .meta_window_state
            .meta_popups
            .get(meta_popup_id)
            .cloned()
        else {
            return;
        };
        if !self.xdg_popups.contains_key(&popup.surface_id) {
            return;
        }
        let Some(geometry) = popup.geometry.as_ref().map(|geometry| geometry.0) else {
            return;
        };
        let Some(bounds) = self.meta_window_state.popup_tile_bounds(&popup.parent) else {
            return;
        };
        if geometry.size.w <= 0 || geometry.size.h <= 0 {
            return;
        }

        let position = clamped_popup_position(popup.position.0, geometry, bounds);
        if position == popup.position.0 {
            return;
        }

        let dx = position.x - popup.position.0.x;
        let dy = position.y - popup.position.0.y;
        let position = MyPoint::from(position);
        tracing::debug!(
            target: "veshell::geometry",
            popup_id = %meta_popup_id,
            old_position = ?popup.position.0,
            new_position = ?position.0,
            bounds = ?bounds,
            geometry = ?geometry,
            "clamping popup inside the tile"
        );
        self.patch_meta_popup(
            MetaPopupPatch::UpdatePosition {
                id: meta_popup_id.to_string(),
                value: position,
            },
            true,
        );
        self.translate_pointer_focus_offset_for_surface(
            popup.surface_id,
            f64::from(dx),
            f64::from(dy),
        );
    }

    /// Translate X11 override-redirect children when the owning tile moves.
    ///
    /// X11 popups are independent root windows; moving the parent window is
    /// not enough. Their native roots move with the tile while their
    /// tile-relative model positions stay unchanged.
    pub fn translate_x11_popups_for_root(&mut self, parent_meta_window_id: &str, dx: i32, dy: i32) {
        if dx == 0 && dy == 0 {
            return;
        }
        let popups: Vec<(String, u64, MyPoint<i32, Logical>)> = self
            .meta_window_state
            .meta_popups
            .values()
            .filter(|popup| popup.parent == parent_meta_window_id)
            .filter_map(|popup| {
                popup
                    .native_root
                    .clone()
                    .map(|native_root| (popup.id.clone(), popup.surface_id, native_root))
            })
            .collect();
        for (popup_id, surface_id, native_root) in popups {
            let Some(wl_surface) = self.surfaces.get(&surface_id).cloned() else {
                continue;
            };
            let Some(x11_surface) = self.x11_surface_per_wl_surface.get(&wl_surface).cloned()
            else {
                continue;
            };
            let mut configure = x11_surface.last_configure();
            configure.loc = Point::from((native_root.0.x + dx, native_root.0.y + dy));
            if x11_surface.configure(configure).is_ok() {
                if let Some(popup) = self.meta_window_state.meta_popups.get_mut(&popup_id) {
                    popup.native_root = Some(configure.loc.into());
                }
                self.translate_pointer_focus_offset_for_surface(
                    surface_id,
                    f64::from(dx),
                    f64::from(dy),
                );
            }
        }
    }

    /// Recompute Wayland popup positions from their stored parent-relative
    /// protocol coordinates after the parent's tile/render origin becomes
    /// available or changes.
    pub fn renormalize_wayland_popups_for_root(&mut self, parent_meta_window_id: &str) {
        let popups: Vec<(String, MyPoint<i32, Logical>, MyPoint<i32, Logical>)> = self
            .meta_window_state
            .meta_popups
            .values()
            .filter(|popup| popup.parent == parent_meta_window_id)
            .filter_map(|popup| {
                let parent_relative = popup.parent_relative.clone()?;
                let normalized = self
                    .meta_window_state
                    .popup_tile_position(parent_meta_window_id, parent_relative.0)?;
                Some((
                    popup.id.clone(),
                    popup.position.clone(),
                    MyPoint::from(normalized),
                ))
            })
            .filter(|(_, current, next)| current.0 != next.0)
            .collect();
        for (popup_id, _, position) in popups {
            self.patch_meta_popup(
                MetaPopupPatch::UpdatePosition {
                    id: popup_id,
                    value: position,
                },
                true,
            );
        }
    }

    pub fn remove_meta_popup(&mut self, meta_popup_id: &String) {
        // Role teardown and surface destruction can both report the same popup.
        // Emit one removal event and clear the reverse mapping on the first
        // pass; later passes are no-ops.
        self.meta_window_state
            .meta_popup_id_per_surface_id
            .retain(|_, id| id != meta_popup_id);
        let Some(removed) = self.meta_window_state.meta_popups.remove(meta_popup_id) else {
            return;
        };
        if self
            .popup_pointer_grab
            .is_some_and(|grab| grab.surface_id == removed.surface_id)
        {
            self.popup_pointer_grab = None;
        }

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "meta_popup_removed",
            Some(Box::new(json!({"id":meta_popup_id.clone()}))),
            None,
        );
    }
}

/// Clamp a popup box origin so its client surface stays inside the tile.
fn clamped_popup_position(
    position: Point<i32, Logical>,
    geometry: Rectangle<i32, Logical>,
    bounds: Size<i32, Logical>,
) -> Point<i32, Logical> {
    let offset = geometry.loc;
    let surface_x = position.x - offset.x;
    let surface_y = position.y - offset.y;
    let max_x = (bounds.w - geometry.size.w).max(0);
    let max_y = (bounds.h - geometry.size.h).max(0);
    Point::from((
        surface_x.clamp(0, max_x) + offset.x,
        surface_y.clamp(0, max_y) + offset.y,
    ))
}

#[cfg(test)]
mod tests {
    use super::clamped_popup_position;
    use smithay::utils::{Logical, Point, Rectangle, Size};

    #[test]
    fn clamps_a_popup_below_the_tile_back_inside() {
        let position = Point::from((2091, 1511));
        let geometry = Rectangle::new((24, 12).into(), (421, 834).into());
        let bounds = Size::from((2512, 1392));

        assert_eq!(
            clamped_popup_position(position, geometry, bounds),
            Point::from((2091, 570))
        );
    }

    #[test]
    fn leaves_a_contained_popup_untouched() {
        let position = Point::from((2091, 400));
        let geometry = Rectangle::new((24, 12).into(), (421, 834).into());
        let bounds = Size::from((2512, 1392));

        assert_eq!(clamped_popup_position(position, geometry, bounds), position);
    }
}
