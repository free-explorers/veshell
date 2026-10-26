//! Interactive move for windows owned by a floating tile.
//!
//! Floating mode is the escape hatch for X11 applications (Zoom et al.) and for
//! client-side-decorated Wayland toplevels such as Firefox. X11 clients have a
//! real root position that drives their own panels, popups and pointer
//! coordinates; a Wayland toplevel is moved by the shell publishing a new box
//! origin. Moving only the Flutter box would make an X11 window's two positions
//! diverge; the result is the pointer feedback loop fixed by this module.
//!
//! The move is deliberately small: there is no general pointer-grab
//! infrastructure in this compositor, so we track the in-progress move in
//! [`State`] and apply it from the normal pointer-motion path. Motion is not
//! forwarded to the client while the move is active, which is the same contract
//! a regular compositor grab provides. Tiled and maximized windows are never
//! eligible.

use smithay::{
    input::pointer::CursorIcon,
    utils::{Logical, Point, Rectangle, Size},
    wayland::seat::WaylandFocus,
};

use crate::{
    backend::Backend,
    focus::PointerFocusTarget,
    meta_window_state::meta_resize_edge::MetaResizeEdge,
    meta_window_state::meta_window::{MetaWindow, MetaWindowPatch, WindowPlacement},
    state::State,
};

/// An in-progress interactive move.
#[derive(Clone, Debug)]
pub struct FloatingMove {
    pub meta_window_id: String,
    /// `pointer - window.position` at the start of the move, in global logical
    /// coordinates. Keeping the offset (rather than the pointer position) means
    /// grabbing a window at its bottom-right corner does not snap it.
    pub grab_offset: Point<f64, Logical>,
}

/// An in-progress compositor-owned resize.
#[derive(Clone, Debug)]
pub struct FloatingResize {
    pub meta_window_id: String,
    pub edge: MetaResizeEdge,
    pub initial_pointer: Point<f64, Logical>,
    pub initial_placement: WindowPlacement,
}

/// Whether a floating window may start a compositor-owned resize.
///
/// Server-decorated windows use the same path as client-decorated ones: the
/// resize targets the client surface, while Flutter adds the shell title bar
/// around the published client size.
pub(crate) fn can_resize_floating(meta_window: &MetaWindow, edge: MetaResizeEdge) -> bool {
    meta_window.is_floating()
        && !meta_window.client_maximized
        && !meta_window.is_fullscreen
        && !meta_window.is_fixed_sized
        && edge != MetaResizeEdge::NONE
}

fn resize_cursor(edge: MetaResizeEdge) -> CursorIcon {
    let left = edge.contains(MetaResizeEdge::LEFT);
    let right = edge.contains(MetaResizeEdge::RIGHT);
    let top = edge.contains(MetaResizeEdge::TOP);
    let bottom = edge.contains(MetaResizeEdge::BOTTOM);
    match (left, right, top, bottom) {
        (true, _, true, _) | (_, true, _, true) => CursorIcon::NwseResize,
        (_, true, true, _) | (true, _, _, true) => CursorIcon::NeswResize,
        (true, true, _, _) => CursorIcon::EwResize,
        (_, _, true, true) => CursorIcon::NsResize,
        (true, _, _, _) | (_, true, _, _) => CursorIcon::EwResize,
        (_, _, true, _) | (_, _, _, true) => CursorIcon::NsResize,
        _ => CursorIcon::Default,
    }
}

impl<BackendData: Backend + 'static> State<BackendData> {
    /// Starts a compositor-owned resize for a floating window.
    pub fn start_floating_resize(
        &mut self,
        meta_window_id: String,
        edge: MetaResizeEdge,
        pointer: Point<f64, Logical>,
    ) -> bool {
        let Some(meta_window) = self.meta_window_state.meta_windows.get(&meta_window_id) else {
            return false;
        };
        if !can_resize_floating(meta_window, edge) {
            tracing::debug!(
                target: "veshell::geometry",
                meta_window_id = %meta_window_id,
                display_mode = ?meta_window.display_mode,
                client_maximized = meta_window.client_maximized,
                is_fullscreen = meta_window.is_fullscreen,
                is_fixed_sized = meta_window.is_fixed_sized,
                ?edge,
                "floating resize rejected by window state"
            );
            return false;
        }
        let Some(mut placement) = meta_window.window_placement() else {
            tracing::debug!(
                target: "veshell::geometry",
                meta_window_id = %meta_window_id,
                position = ?meta_window.position,
                geometry = ?meta_window.geometry,
                "floating resize rejected without a placement"
            );
            return false;
        };
        if let Some(size) = self.floating_size(meta_window) {
            placement.client_size = size;
        }
        self.floating_resize = Some(FloatingResize {
            meta_window_id,
            edge,
            initial_pointer: pointer,
            initial_placement: placement,
        });
        self.cursor_state
            .lock()
            .expect("cursor state lock")
            .set_shape(resize_cursor(edge));
        true
    }

    /// Updates the active resize from the current pointer position.
    pub fn update_floating_resize(&mut self, pointer: Point<f64, Logical>) {
        let Some(resize) = self.floating_resize.clone() else {
            return;
        };
        let Some(meta_window) = self
            .meta_window_state
            .meta_windows
            .get(&resize.meta_window_id)
            .cloned()
        else {
            self.floating_resize = None;
            return;
        };
        if !meta_window.is_floating() {
            self.floating_resize = None;
            return;
        }

        let delta = Point::from((
            pointer.x - resize.initial_pointer.x,
            pointer.y - resize.initial_pointer.y,
        ));
        let rect = resize_rect(resize.edge, resize.initial_placement, delta);
        self.patch_meta_window(
            MetaWindowPatch::SetWindowRect {
                id: meta_window.id.clone(),
                value: Some(rect.into()),
                is_floating_mode: true,
            },
            true,
        );
    }

    /// Ends the active resize, if any.
    pub fn end_floating_resize(&mut self) {
        if self.floating_resize.take().is_some() {
            self.cursor_state
                .lock()
                .expect("cursor state lock")
                .unset_shape();
        }
    }

    /// Refreshes the stored pointer basis for a floating window after the
    /// compositor applied its native position.
    ///
    /// Floating mode is the one place where the native/global position is the
    /// authoritative pointer basis, and the compositor owns the pointer while
    /// it moves the window. Non-floating windows must never call this: their
    /// pointer basis is Flutter's render origin.
    pub fn update_floating_pointer_basis(
        &mut self,
        meta_window: &MetaWindow,
        box_position: Point<f64, Logical>,
    ) {
        if !meta_window.is_floating() {
            return;
        }
        let Some(surface) = self.surfaces.get(&meta_window.surface_id) else {
            return;
        };
        let Some((target, _)) = self.pointer_focus.as_ref() else {
            return;
        };
        if target.wl_surface().as_deref() != Some(surface) {
            return;
        }
        let target = target.clone();
        self.pointer_focus = Some((target, meta_window.surface_origin_at(box_position)));
    }

    /// Starts an interactive move if the window is owned by a floating tile and
    /// has a known native position. Returns whether a move was started.
    pub fn start_floating_move(
        &mut self,
        meta_window_id: String,
        pointer: Point<f64, Logical>,
    ) -> bool {
        let Some(meta_window) = self.meta_window_state.meta_windows.get(&meta_window_id) else {
            return false;
        };
        if !meta_window.is_floating() || meta_window.client_maximized {
            // A maximized floating window is drawn at the tile origin; moving
            // only the native window would desynchronise the box.
            tracing::debug!(
                target: "veshell::geometry",
                meta_window_id = %meta_window_id,
                display_mode = ?meta_window.display_mode,
                client_maximized = meta_window.client_maximized,
                "floating move rejected by window state"
            );
            return false;
        }
        let Some(origin) = meta_window.position.as_ref() else {
            // The shell has not placed this floating window yet.
            tracing::debug!(
                target: "veshell::geometry",
                meta_window_id = %meta_window_id,
                viewport = ?meta_window.viewport,
                geometry = ?meta_window.geometry,
                "floating move rejected without a placement"
            );
            return false;
        };
        self.floating_move = Some(FloatingMove {
            meta_window_id,
            grab_offset: pointer - Point::from((f64::from(origin.0.x), f64::from(origin.0.y))),
        });
        true
    }

    /// Updates the moving window from the current pointer position. Called from
    /// the pointer-motion path; the caller is responsible for not forwarding the
    /// motion to the client while a move is active.
    pub fn update_floating_move(&mut self, pointer: Point<f64, Logical>) {
        let Some(move_) = self.floating_move.clone() else {
            return;
        };
        let Some(meta_window) = self
            .meta_window_state
            .meta_windows
            .get(&move_.meta_window_id)
            .cloned()
        else {
            self.floating_move = None;
            return;
        };
        if !meta_window.is_floating() {
            self.floating_move = None;
            return;
        }

        let position = pointer - move_.grab_offset;
        let clamped = self.clamp_to_viewport_for_move(&meta_window, position);
        let before_focus = self.pointer_focus.as_ref().map(|(_, offset)| *offset);
        let size = self
            .x11_surface_for_meta_window(&meta_window)
            .map(|surface| surface.last_configure().size);
        self.apply_floating_position(&meta_window, clamped, true, true);
    }

    /// Ends the current move, if any.
    pub fn end_floating_move(&mut self) {
        self.floating_move = None;
    }

    /// Moves a floating window to `position` (global logical).
    ///
    /// Used by the shell-initiated move and by the client `move_request` path.
    /// Only X11 windows are configured natively; the model/patch is updated for
    /// every floating window so the shell can follow.
    pub fn move_floating_window(&mut self, meta_window_id: &str, position: Point<f64, Logical>) {
        let Some(meta_window) = self
            .meta_window_state
            .meta_windows
            .get(meta_window_id)
            .cloned()
        else {
            return;
        };
        if !meta_window.is_floating() {
            return;
        }
        let position = self.clamp_to_viewport(&meta_window, position);
        self.apply_floating_position(&meta_window, position, true, true);
    }

    /// Clamps an explicitly placed floating window inside its tile.
    ///
    /// A client can request `(0,0)` before the floating rect is known; this
    /// brings the native position back into the tile once the rect arrives, so
    /// the rendered box and the client stay in sync.
    pub fn clamp_floating_window(&mut self, meta_window_id: &str) {
        let Some(meta_window) = self
            .meta_window_state
            .meta_windows
            .get(meta_window_id)
            .cloned()
        else {
            return;
        };
        if !meta_window.is_floating() || meta_window.client_maximized {
            return;
        }
        let Some(position) = meta_window.position.as_ref() else {
            return;
        };
        let position = Point::from((f64::from(position.0.x), f64::from(position.0.y)));
        let clamped = self.clamp_to_viewport(&meta_window, position);
        if clamped != position {
            self.apply_floating_position(&meta_window, clamped, false, true);
        }
    }

    /// Translates a floating window by a tile-origin delta.
    ///
    /// Called when the workspace/tile slides; keeping the native position in
    /// step preserves the window's tile-relative placement.
    pub fn translate_floating_window(&mut self, meta_window_id: &str, dx: i32, dy: i32) {
        if dx == 0 && dy == 0 {
            return;
        }
        let Some(meta_window) = self
            .meta_window_state
            .meta_windows
            .get(meta_window_id)
            .cloned()
        else {
            return;
        };
        if !meta_window.is_floating() || meta_window.client_maximized {
            return;
        }
        let Some(position) = meta_window.position.as_ref() else {
            return;
        };
        let position = Point::from((
            f64::from(position.0.x) + f64::from(dx),
            f64::from(position.0.y) + f64::from(dy),
        ));
        self.apply_floating_position(&meta_window, position, false, false);
    }

    /// Centres an unplaced floating window inside its tile.
    ///
    /// This is the single initial-placement path for both backends: X11 gets a
    /// native configure at the returned origin, Wayland gets the same origin in
    /// the model so the shell renders the first frame there. The shell only
    /// publishes the measured viewport/size; it does not choose a position.
    /// Called when the floating rect is published or when the client's first
    /// geometry arrives after the viewport.
    pub fn center_floating_window(&mut self, meta_window_id: &str) {
        let Some(meta_window) = self
            .meta_window_state
            .meta_windows
            .get(meta_window_id)
            .cloned()
        else {
            return;
        };
        if !meta_window.is_floating()
            || meta_window.position_explicit
            || meta_window.client_maximized
        {
            return;
        }
        let Some(rect) = meta_window.viewport.as_ref() else {
            return;
        };
        let Some(size) = self.floating_size(&meta_window) else {
            return;
        };
        let geometry_offset = meta_window
            .geometry
            .as_ref()
            .map(|geometry| geometry.0.loc)
            .unwrap_or_else(|| Point::from((0, 0)));
        let placement = centered_placement(rect.0, size, geometry_offset);
        if let Some(current) = meta_window.position.as_ref() {
            if current.0 == placement.origin {
                // The viewport is republished on every floating-state change;
                // re-configuring an already centred window would make clients
                // flicker or hide transient panels.
                return;
            }
        }
        self.apply_floating_position(
            &meta_window,
            Point::from((f64::from(placement.origin.x), f64::from(placement.origin.y))),
            false,
            true,
        );
    }

    fn apply_floating_position(
        &mut self,
        meta_window: &MetaWindow,
        position: Point<f64, Logical>,
        mark_explicit: bool,
        follow_wayland_popups: bool,
    ) {
        let logical = Point::from((position.x.round() as i32, position.y.round() as i32));
        let previous_position = meta_window.position.as_ref().map(|position| position.0);

        // Configure the native X11 window first, then publish the observed
        // position. The shell renders from `position`; keeping the native
        // window and the model in lockstep is what closes the pointer loop.
        if let Some(wl_surface) = self.surfaces.get(&meta_window.surface_id).cloned() {
            if mark_explicit {
                // The compositor owns the pointer during the move. Publish the
                // moving window as the focus target before configuring, so a
                // fast drag cannot release with the pre-move basis.
                self.pointer_focus = Some((
                    PointerFocusTarget::from(&wl_surface),
                    meta_window.surface_origin_at(Point::from((
                        f64::from(logical.x),
                        f64::from(logical.y),
                    ))),
                ));
            }
            if let Some(x11_surface) = self.x11_surface_per_wl_surface.get(&wl_surface).cloned() {
                let mut rect = x11_surface.last_configure();
                if rect.size.w <= 0 || rect.size.h <= 0 {
                    return;
                }
                rect.loc = logical;
                if let Err(err) = x11_surface.configure(rect) {
                    tracing::warn!(
                        meta_window_id = %meta_window.id,
                        ?err,
                        "failed to configure floating X11 move"
                    );
                }
            }
        }

        self.update_floating_pointer_basis(
            meta_window,
            Point::from((f64::from(logical.x), f64::from(logical.y))),
        );

        if mark_explicit && !meta_window.position_explicit {
            self.patch_meta_window(
                MetaWindowPatch::UpdatePositionExplicit {
                    id: meta_window.id.clone(),
                    value: true,
                },
                true,
            );
        }
        self.patch_meta_window(
            MetaWindowPatch::UpdatePosition {
                id: meta_window.id.clone(),
                value: Some(logical.into()),
            },
            true,
        );
        if follow_wayland_popups {
            if let Some(previous_position) = previous_position {
                self.translate_wayland_popups_for_root(
                    &meta_window.id,
                    logical.x - previous_position.x,
                    logical.y - previous_position.y,
                );
            }
        }
    }

    fn clamp_to_viewport(
        &self,
        meta_window: &MetaWindow,
        position: Point<f64, Logical>,
    ) -> Point<f64, Logical> {
        let Some(rect) = meta_window.viewport.as_ref() else {
            return position;
        };
        if rect.0.size.w <= 0 || rect.0.size.h <= 0 {
            // A content rect can be measured as empty for one frame while the
            // tile is being attached; clamping to it would pin every floating
            // window to the tile origin.
            return position;
        }
        let Some(size) = self.floating_size(meta_window) else {
            return position;
        };

        clamp_position(rect.0, size, position)
    }

    /// Clamping for a compositor-owned move. A window at least as large as the
    /// tile can still be dragged: at least a title-bar-sized edge stays
    /// visible. The strict `clamp_position` policy is kept for client-driven
    /// placement, where a panel must stay inside its tile.
    fn clamp_to_viewport_for_move(
        &self,
        meta_window: &MetaWindow,
        position: Point<f64, Logical>,
    ) -> Point<f64, Logical> {
        let Some(rect) = meta_window.viewport.as_ref() else {
            return position;
        };
        if rect.0.size.w <= 0 || rect.0.size.h <= 0 {
            return position;
        }
        let Some(size) = self.floating_size(meta_window) else {
            return position;
        };

        clamp_position_for_move(rect.0, size, position)
    }

    fn floating_size(&self, meta_window: &MetaWindow) -> Option<Size<i32, Logical>> {
        let size = self
            .x11_surface_for_meta_window(meta_window)
            .map(|surface| surface.last_configure().size)
            .or_else(|| {
                meta_window
                    .geometry
                    .as_ref()
                    .map(|geometry| geometry.0.size)
            })?;
        (size.w > 0 && size.h > 0).then_some(size)
    }

    fn x11_surface_for_meta_window(
        &self,
        meta_window: &MetaWindow,
    ) -> Option<smithay::xwayland::X11Surface> {
        let wl_surface = self.surfaces.get(&meta_window.surface_id)?;
        self.x11_surface_per_wl_surface.get(wl_surface).cloned()
    }
}

/// The initial placement for an unplaced floating window.
///
/// Shared by Wayland and X11: the origin is centred inside the floating
/// viewport and the client size/geometry offset come from the same placement
/// model the gesture paths use.
pub(crate) fn centered_placement(
    viewport: Rectangle<i32, Logical>,
    client_size: Size<i32, Logical>,
    geometry_offset: Point<i32, Logical>,
) -> WindowPlacement {
    let x = f64::from(viewport.loc.x) + f64::from(viewport.size.w - client_size.w) / 2.0;
    let y = f64::from(viewport.loc.y) + f64::from(viewport.size.h - client_size.h) / 2.0;
    WindowPlacement {
        origin: Point::from((x.round() as i32, y.round() as i32)),
        client_size,
        geometry_offset,
    }
}

/// Clamps a client-surface position to `rect` for a window of `size`.
///
/// `rect` is the global client-surface area of the floating tile (decoration
/// already excluded by the shell). A window bigger than the rect is pinned to
/// its origin rather than producing an inverted clamp range.
pub(crate) fn clamp_position(
    rect: Rectangle<i32, Logical>,
    size: Size<i32, Logical>,
    position: Point<f64, Logical>,
) -> Point<f64, Logical> {
    let min_x = f64::from(rect.loc.x);
    let min_y = f64::from(rect.loc.y);
    let max_x = f64::from(rect.loc.x + rect.size.w - size.w);
    let max_y = f64::from(rect.loc.y + rect.size.h - size.h);

    Point::from((
        position.x.clamp(min_x, max_x.max(min_x)),
        position.y.clamp(min_y, max_y.max(min_y)),
    ))
}

/// Clamps a compositor-moved window so at least half of it stays inside the
/// floating viewport on each axis.
///
/// A window may extend outside the tile by at most half of its own width and
/// height. This is uniform for small, viewport-sized and oversized windows; it
/// avoids special-casing “at least as large as the tile” and still leaves a
/// predictable recovery area.
pub(crate) fn clamp_position_for_move(
    rect: Rectangle<i32, Logical>,
    size: Size<i32, Logical>,
    position: Point<f64, Logical>,
) -> Point<f64, Logical> {
    let half_width = f64::from(size.w) / 2.0;
    let half_height = f64::from(size.h) / 2.0;
    let min_x = f64::from(rect.loc.x) - half_width;
    let max_x = f64::from(rect.loc.x + rect.size.w) - half_width;
    let min_y = f64::from(rect.loc.y) - half_height;
    let max_y = f64::from(rect.loc.y + rect.size.h) - half_height;

    Point::from((
        position.x.clamp(min_x, max_x.max(min_x)),
        position.y.clamp(min_y, max_y.max(min_y)),
    ))
}

/// Computes a resized client-surface rect from an edge drag.
pub(crate) fn resize_rect(
    edge: MetaResizeEdge,
    initial: WindowPlacement,
    delta: Point<f64, Logical>,
) -> Rectangle<i32, Logical> {
    let mut x = f64::from(initial.origin.x);
    let mut y = f64::from(initial.origin.y);
    let mut width = f64::from(initial.client_size.w);
    let mut height = f64::from(initial.client_size.h);

    if edge.contains(MetaResizeEdge::LEFT) {
        x += delta.x;
        width -= delta.x;
    }
    if edge.contains(MetaResizeEdge::RIGHT) {
        width += delta.x;
    }
    if edge.contains(MetaResizeEdge::TOP) {
        y += delta.y;
        height -= delta.y;
    }
    if edge.contains(MetaResizeEdge::BOTTOM) {
        height += delta.y;
    }

    let min_size = 1.0;
    if width < min_size {
        if edge.contains(MetaResizeEdge::LEFT) {
            x = f64::from(initial.origin.x + initial.client_size.w) - min_size;
        }
        width = min_size;
    }
    if height < min_size {
        if edge.contains(MetaResizeEdge::TOP) {
            y = f64::from(initial.origin.y + initial.client_size.h) - min_size;
        }
        height = min_size;
    }

    Rectangle::new(
        Point::from((x.round() as i32, y.round() as i32)),
        Size::from((width.round() as i32, height.round() as i32)),
    )
}

#[cfg(test)]
mod tests {
    use super::{centered_placement, clamp_position, clamp_position_for_move, resize_rect};
    use crate::meta_window_state::meta_resize_edge::MetaResizeEdge;
    use crate::meta_window_state::meta_window::WindowPlacement;
    use smithay::utils::{Logical, Point, Rectangle, Size};

    fn rect() -> Rectangle<i32, Logical> {
        Rectangle::new((100, 200).into(), (800, 600).into())
    }

    fn size() -> Size<i32, Logical> {
        (300, 200).into()
    }

    #[test]
    fn centres_the_initial_placement_in_the_viewport() {
        let placement = centered_placement(rect(), size(), Point::from((24, 21)));

        assert_eq!(placement.origin, Point::from((350, 400)));
        assert_eq!(placement.client_size, size());
        assert_eq!(placement.geometry_offset, Point::from((24, 21)));
        assert_eq!(placement.surface_origin(), Point::from((326.0, 379.0)));
    }

    #[test]
    fn keeps_a_position_inside_the_tile() {
        assert_eq!(
            clamp_position(rect(), size(), Point::from((250.0, 300.0))),
            Point::from((250.0, 300.0))
        );
    }

    #[test]
    fn clamps_to_the_top_left() {
        assert_eq!(
            clamp_position(rect(), size(), Point::from((-50.0, -10.0))),
            Point::from((100.0, 200.0))
        );
    }

    #[test]
    fn clamps_to_the_bottom_right() {
        assert_eq!(
            clamp_position(rect(), size(), Point::from((2000.0, 2000.0))),
            Point::from((600.0, 600.0))
        );
    }

    #[test]
    fn pins_an_oversized_window_to_the_origin() {
        assert_eq!(
            clamp_position(rect(), (1000, 800).into(), Point::from((300.0, 300.0))),
            Point::from((100.0, 200.0))
        );
    }

    #[test]
    fn a_small_window_can_move_half_its_size_outside() {
        assert_eq!(
            clamp_position_for_move(rect(), size(), Point::from((900.0, 900.0))),
            Point::from((750.0, 700.0))
        );
        assert_eq!(
            clamp_position_for_move(rect(), size(), Point::from((-500.0, -500.0))),
            Point::from((-50.0, 100.0))
        );
    }

    #[test]
    fn a_viewport_sized_window_can_move_half_its_size_outside() {
        let viewport = Rectangle::new((100, 200).into(), (800, 600).into());
        let size = (800, 600).into();

        assert_eq!(
            clamp_position_for_move(viewport, size, Point::from((300.0, 400.0))),
            Point::from((300.0, 400.0))
        );
        assert_eq!(
            clamp_position_for_move(viewport, size, Point::from((-2000.0, 2000.0))),
            Point::from((-300.0, 500.0))
        );
    }

    #[test]
    fn an_oversized_window_can_move_half_its_size_outside() {
        let viewport = Rectangle::new((100, 200).into(), (800, 600).into());
        let size = (1000, 800).into();

        assert_eq!(
            clamp_position_for_move(viewport, size, Point::from((-5000.0, 5000.0))),
            Point::from((-400.0, 400.0))
        );
    }

    #[test]
    fn resize_from_the_top_left_moves_position_and_shrinks_the_rect() {
        assert_eq!(
            resize_rect(
                MetaResizeEdge::TOP_LEFT,
                WindowPlacement {
                    origin: Point::from((100, 100)),
                    client_size: (200, 150).into(),
                    geometry_offset: Point::from((0, 0)),
                },
                Point::from((50.0, 30.0)),
            ),
            Rectangle::new((150, 130).into(), (150, 120).into())
        );
    }

    #[test]
    fn resize_from_the_bottom_right_only_changes_size() {
        assert_eq!(
            resize_rect(
                MetaResizeEdge::BOTTOM_RIGHT,
                WindowPlacement {
                    origin: Point::from((100, 100)),
                    client_size: (200, 150).into(),
                    geometry_offset: Point::from((0, 0)),
                },
                Point::from((50.0, 30.0)),
            ),
            Rectangle::new((100, 100).into(), (250, 180).into())
        );
    }

    #[test]
    fn resize_never_goes_below_one_pixel() {
        assert_eq!(
            resize_rect(
                MetaResizeEdge::RIGHT,
                WindowPlacement {
                    origin: Point::from((100, 100)),
                    client_size: (200, 150).into(),
                    geometry_offset: Point::from((0, 0)),
                },
                Point::from((-500.0, 0.0)),
            ),
            Rectangle::new((100, 100).into(), (1, 150).into())
        );
    }
}
