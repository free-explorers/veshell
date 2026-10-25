use serde::{Deserialize, Serialize};
use serde_json::json;
use smithay::{
    reexports::wayland_protocols::xdg::{
        decoration::zv1::server::zxdg_toplevel_decoration_v1::Mode as DecorationMode,
        shell::server::xdg_toplevel,
    },
    utils::{Logical, Point, Rectangle, Size, Transform},
    wayland::{
        compositor::{send_surface_state, with_states},
        fractional_scale::with_fractional_scale,
        seat::WaylandFocus,
        shell::xdg::XDG_TOPLEVEL_ROLE,
        xwayland_shell::XWAYLAND_SHELL_ROLE,
    },
    xwayland::XWaylandClientData,
};
use tracing::{info, warn};

use crate::{
    backend::Backend,
    flutter_engine::wayland_messages::{MyPoint, MyRectangle},
    focus::PointerFocusTarget,
    state::State,
};

use super::{determine_desktop_file_app_id_from_pid, meta_popup::MetaPopup};

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub enum DisplayMode {
    Maximized,
    Fullscreen,
    Floating,
}

#[derive(Serialize, Deserialize, Clone)]
#[serde(tag = "type")]
pub enum MetaWindowPatch {
    UpdateAppId {
        id: String,
        value: Option<String>,
    },
    /// Client-declared transient relation (`xdg_toplevel.set_parent`, X11
    /// transient). Authoritative: the window is a dialog of its owner's tile.
    UpdateParent {
        id: String,
        value: Option<String>,
    },
    /// `xdg_activation_v1` "opened from" relation: the surface the requesting
    /// client declared as the opener. Only an owner hint, never a dialog
    /// trigger on its own; a token that declares no surface records none.
    UpdateActivatedBy {
        id: String,
        value: Option<String>,
    },
    UpdateTitle {
        id: String,
        value: Option<String>,
    },
    UpdatePid {
        id: String,
        value: i32,
    },
    UpdateWindowClass {
        id: String,
        value: Option<String>,
    },
    UpdateStartupId {
        id: String,
        value: Option<String>,
    },
    UpdateIsFixedSized {
        id: String,
        value: bool,
    },
    UpdateIsModal {
        id: String,
        value: bool,
    },
    /// Whether the toplevel negotiates a fullscreen state (client-requested or
    /// shell-requested). A fullscreen window is a top-level application surface,
    /// so the shell extracts it to its own tile instead of turning it into a
    /// dialog on a relation.
    UpdateIsFullscreen {
        id: String,
        value: bool,
    },
    /// A client-side decoration maximize/restore request.
    UpdateClientMaximized {
        id: String,
        value: bool,
    },
    UpdateSkipTaskbar {
        id: String,
        value: bool,
    },
    UpdateKeepOnTop {
        id: String,
        value: bool,
    },
    UpdateDisplayMode {
        id: String,
        value: Option<DisplayMode>,
    },
    /// The global logical viewport a floating tile lets the client surface
    /// occupy.
    ///
    /// Floating ownership is derived from [`MetaWindow::display_mode`]; this
    /// message carries only the measured viewport/origin used by the coordinate
    /// gateway to clamp and translate native moves.
    UpdateViewport {
        id: String,
        value: Option<MyRectangle<i32, Logical>>,
        /// The tile content origin in global coordinates. A change translates
        /// the floating window by the same delta so it keeps its tile-relative
        /// position when the workspace slides.
        origin: Option<MyPoint<i32, Logical>>,
    },
    UpdateMapped {
        id: String,
        value: bool,
    },
    UpdatePosition {
        id: String,
        value: Option<MyPoint<i32, Logical>>,
    },
    /// Whether the client explicitly placed the window (X11 configure request
    /// with x/y). Distinguishes a real `(0,0)` placement from the legacy
    /// launch-time origin used for tiled windows, so a floating window that
    /// never placed itself can be centred.
    UpdatePositionExplicit {
        id: String,
        value: bool,
    },
    /// The compositor-global origin of the client surface as rendered by
    /// Flutter. Unlike `position`, this is valid for tiled windows whose
    /// native X11 position is synthetic.
    UpdateRenderOrigin {
        id: String,
        value: Option<MyPoint<i32, Logical>>,
    },
    /// Surface-local geometry. Never a native/global window position.
    UpdateGeometry {
        id: String,
        value: Option<MyRectangle<i32, Logical>>,
    },
    /// Moves/resizes a floating window in compositor-global coordinates.
    ///
    /// Kept separate from [`MetaWindowPatch::UpdateGeometry`] so a bare Rect
    /// has one meaning per message. The boolean makes the coordinate space
    /// explicit at the boundary instead of relying on an asynchronous display
    /// mode lookup.
    SetWindowRect {
        id: String,
        value: Option<MyRectangle<i32, Logical>>,
        #[serde(rename = "isFloatingMode")]
        is_floating_mode: bool,
    },
    UpdateNeedDecoration {
        id: String,
        value: bool,
    },
    UpdateGameModeActivated {
        id: String,
        value: bool,
    },
    /// Marks the MetaWindow a live screen cast is recording (see
    /// [`crate::portal::service::sync_recording_meta_windows`]). Patched by the
    /// compositor, so the shell renders the indicator from window state.
    UpdateIsRecording {
        id: String,
        value: bool,
    },
    UpdateCurrentOutput {
        id: String,
        value: Option<String>,
    },
    UpdateScaleRatio {
        id: String,
        value: f64,
    },
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct MetaWindow {
    pub id: String,
    pub app_id: Option<String>,
    /// The owning process's binary name (`/proc/<pid>/comm`), captured at
    /// creation. It is a second identity for casts whose PipeWire consumer node
    /// names the binary rather than a desktop id (Chromium sets
    /// `node.name=brave` while the window's app id is `brave-browser`).
    pub binary_name: Option<String>,
    pub pid: i32,
    pub surface_id: u64,
    /// Client-declared parent (`xdg_toplevel.set_parent`, X11 transient).
    pub parent: Option<String>,
    /// `xdg_activation_v1` requester: the window this one was opened from, as
    /// declared by the requesting client. An owner hint only; unlike
    /// [`MetaWindow::parent`] it never makes the window a dialog by itself. A
    /// token that declares no requesting surface records no relation (the
    /// compositor does not guess a focused window).
    pub activated_by: Option<String>,
    pub mapped: bool,
    pub display_mode: Option<DisplayMode>,
    pub title: Option<String>,
    pub window_class: Option<String>,
    pub startup_id: Option<String>,
    pub is_fixed_sized: bool,
    pub is_modal: bool,
    /// Client- or shell-negotiated xdg `Fullscreen` / X11 `_NET_WM_STATE_FULLSCREEN`
    /// state. Unlike [`MetaWindow::display_mode`], which is the shell's requested
    /// mode, this reflects the state the toplevel actually acked.
    pub is_fullscreen: bool,
    /// Whether the client asked for this window to be maximized through its
    /// own decoration buttons (`xdg_toplevel.set_maximized`, X11
    /// `_NET_WM_STATE_MAXIMIZED_*`). The shell turns that into filling the
    /// floating window, independent of the tile's own display mode.
    pub client_maximized: bool,
    /// Whether the client asked not to be listed in task bars
    /// (`_NET_WM_STATE_SKIP_TASKBAR`).
    pub skip_taskbar: bool,
    /// Whether the client asked to stay above other windows
    /// (`_NET_WM_STATE_ABOVE`).
    pub keep_on_top: bool,
    /// The window's position on the output, for clients that place themselves
    /// (X11 `ConfigureNotify`). Kept separate from `geometry`, which stays
    /// surface-local: mixing the two shifted the surface inside its box.
    pub position: Option<MyPoint<i32, Logical>>,
    /// Whether `position` came from an explicit client placement (an X11
    /// configure request with x/y), rather than the legacy launch origin.
    /// This is placement provenance, not a coordinate-space flag.
    pub position_explicit: bool,
    /// The compositor-global client-surface origin as rendered by Flutter.
    /// This is the surface-buffer origin, not the decorated window box; it is
    /// the basis popups and pointer focus use for both backends.
    pub render_origin: Option<MyPoint<i32, Logical>>,
    /// The global logical client-surface viewport of the floating tile, used
    /// by the coordinate gateway to clamp native moves. `None` outside a
    /// floating tile or before the area is measured.
    pub viewport: Option<MyRectangle<i32, Logical>>,
    /// The floating tile's content origin in global coordinates. Kept beside
    /// the viewport so a tile/workspace move can translate the native window
    /// by the same delta.
    pub viewport_origin: Option<MyPoint<i32, Logical>>,
    pub geometry: Option<MyRectangle<i32, Logical>>,
    pub need_decoration: bool,
    pub current_output: Option<String>,
    pub scale_ratio: f64,
    pub game_mode_activated: bool,
    /// Whether a live screen-cast session is recording this window. Owned by
    /// the portal: it resolves the cast's consumer process (or app id) to a
    /// MetaWindow and patches this flag, so the shell can render the
    /// recording indicator on the tile and its workspace without re-deriving
    /// the mapping.
    pub is_recording: bool,
}

/// The compositor-global placement of a window box.
///
/// `origin` is the window-box top-left, `client_size` is the configured client
/// surface size, and `geometry_offset` is the client's visible-content offset
/// inside its buffer (non-zero for Wayland CSD shadow margins; zero for X11).
/// The same placement describes both backends; only the adapter that applies
/// it differs.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct WindowPlacement {
    pub origin: Point<i32, Logical>,
    pub client_size: Size<i32, Logical>,
    pub geometry_offset: Point<i32, Logical>,
}

impl WindowPlacement {
    /// The origin pointer coordinates are relative to.
    pub fn surface_origin(&self) -> Point<f64, Logical> {
        Point::from((
            f64::from(self.origin.x - self.geometry_offset.x),
            f64::from(self.origin.y - self.geometry_offset.y),
        ))
    }

    /// The client-surface rect in compositor-global coordinates.
    pub fn client_rect(&self) -> Rectangle<i32, Logical> {
        Rectangle::new(self.origin, self.client_size)
    }
}

impl MetaWindow {
    /// The floating/window-box placement derived from the current model.
    pub fn window_placement(&self) -> Option<WindowPlacement> {
        let origin = self.position.as_ref()?.0;
        let geometry = self.geometry.as_ref()?.0;
        Some(WindowPlacement {
            origin,
            client_size: geometry.size,
            geometry_offset: geometry.loc,
        })
    }

    /// Whether this window's placement authority is the floating escape hatch.
    ///
    /// `display_mode` is stable for the lifetime of a manipulation, so this is
    /// the single source of truth; there is no separate floating flag.
    pub fn is_floating(&self) -> bool {
        matches!(self.display_mode, Some(DisplayMode::Floating))
            // Before the routing patch lands, the viewport is the only
            // floating signal. It is published only by the floating area, so
            // this preserves initial client placement without a separate
            // per-window flag.
            || (self.display_mode.is_none() && self.viewport.is_some())
    }

    /// Whether this window is presented with the dialog overlay.
    ///
    /// Mirrors the shell's `isFloatingDialog` predicate: a client-declared
    /// parent, a modal hint, or a fixed-size client. Regular top-levels that
    /// the dialog area can tab/extract are not included.
    pub fn is_floating_dialog(&self) -> bool {
        self.parent.is_some() || self.is_modal || self.is_fixed_sized
    }

    /// Whether interactive resize is allowed for this window.
    ///
    /// Resize belongs to the floating escape hatch and the dialog overlay
    /// only. Tiled, maximized, fullscreen and game windows are sized by the
    /// tile; accepting a client resize request there would desynchronise the
    /// surface from its tile.
    pub fn allows_interactive_resize(&self) -> bool {
        self.is_floating() || self.is_floating_dialog()
    }

    /// The compositor-global origin of this window's client surface buffer.
    ///
    /// [`MetaWindow::position`] addresses the window box. A Wayland client
    /// with client-side decorations reports a non-zero `geometry.loc`: that is
    /// the visible-content offset inside the surface buffer (the CSD shadow
    /// margin). The surface buffer itself starts at `position - geometry.loc`,
    /// and that is the origin pointer coordinates are relative to. X11 reports
    /// a zero geometry offset, so its root position is returned unchanged.
    pub fn surface_origin(&self) -> Option<Point<f64, Logical>> {
        self.position.as_ref().map(|position| {
            self.surface_origin_at(Point::from((
                f64::from(position.0.x),
                f64::from(position.0.y),
            )))
        })
    }

    /// Converts a window-box position into the surface-buffer origin using the
    /// current geometry offset. See [`MetaWindow::surface_origin`].
    pub fn surface_origin_at(&self, position: Point<f64, Logical>) -> Point<f64, Logical> {
        let geometry = self
            .geometry
            .as_ref()
            .map(|geometry| geometry.0.loc)
            .unwrap_or_else(|| Point::from((0, 0)));
        position - Point::from((f64::from(geometry.x), f64::from(geometry.y)))
    }

    /// The size a maximized or fullscreen xdg toplevel must be configured
    /// with, taken from the geometry the shell last pushed.
    ///
    /// A state-only configure leaves `state.size` unset, which the client
    /// reads as "choose your own size" and can answer with its minimum size
    /// (Chromium does). Carrying the geometry keeps the maximize contract.
    /// `None` while no geometry is known or the window is floating.
    pub fn maximized_size(&self) -> Option<Size<i32, Logical>> {
        match self.display_mode {
            Some(DisplayMode::Maximized | DisplayMode::Fullscreen) => {
                self.geometry.as_ref().map(|rect| rect.0.size)
            }
            _ => None,
        }
    }
}

impl<BackendData: Backend + 'static> State<BackendData> {
    pub fn create_meta_window(&mut self, meta_window: MetaWindow) -> MetaWindow {
        self.meta_window_state
            .meta_windows
            .insert(meta_window.id.clone(), meta_window.clone());

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "meta_window_created",
            Some(Box::new(json!(meta_window))),
            None,
        );
        // A window created while a cast is live may be the recording app's
        // window (app-id fallback): recompute so its tile gets the indicator.
        crate::portal::service::sync_recording_meta_windows(self);
        meta_window
    }

    pub fn remove_meta_window(&mut self, meta_window_id: &String) {
        // Teardown paths can overlap: a client normally unmaps its X11 window
        // (which removes the MetaWindow) and only later destroys the surface,
        // but a crashed client can destroy it without the unmap, and the
        // surface-destroyed handler then asks again. Drop the reverse mapping
        // here and make the removal idempotent so the shell never receives two
        // removal events for one window.
        self.meta_window_state
            .meta_window_id_per_surface_id
            .retain(|_, id| id != meta_window_id);
        if self
            .meta_window_state
            .meta_windows
            .remove(meta_window_id)
            .is_none()
        {
            return;
        }

        // A game that closes itself is torn down through this path, not through
        // an `UpdateGameModeActivated(false)` patch. Without that deactivation
        // the shell never pops its gaming route and the compositor keeps the
        // pointer focus it set on entry, now targeting a freed surface, so
        // Flutter never gets its pointer events back. Deactivate first so both
        // release cleanly: this clears the compositor-set pointer focus, hands
        // the output back its fixed cadence, drops the forwarded keys and tells
        // the shell to leave the mode.
        if self.meta_window_state.meta_window_in_gaming_mode.as_deref()
            == Some(meta_window_id.as_str())
        {
            self.patch_meta_window(
                MetaWindowPatch::UpdateGameModeActivated {
                    id: meta_window_id.clone(),
                    value: false,
                },
                true,
            );
        }

        // Drop it from the focus order too: a removed window can no longer be
        // the recording app's most recently focused window.
        self.meta_window_state.forget_meta_window(meta_window_id);

        // A window-share session cannot survive its window: closing the
        // MetaWindow tears the share down through the ordinary close path
        // (spec 5.3), before the removal event tells the shell the window
        // is gone. Popups of the dead window disappear from the registry
        // with it, so their surfaces stop rendering for any session.
        crate::portal::service::close_source_share_sessions(self, meta_window_id);

        // Backstop for a window that was torn down with the gaming flags out of
        // sync (the deactivation patch above already cleared the focus, the
        // output cadence and the forwarded keys): the client is gone, so the
        // pointer focus must not keep naming it and the next gaming session
        // must start from a clean slate.
        if self.meta_window_state.meta_window_in_gaming_mode.as_deref()
            == Some(meta_window_id.as_str())
        {
            self.meta_window_state.meta_window_in_gaming_mode = None;
            if self.pointer_focus.take().is_some() {
                self.refresh_pointer_focus();
            }
            self.game_mode_forwarded_keys.clear();
        }

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "meta_window_removed",
            Some(Box::new(json!({
                "id": meta_window_id.clone(),
            }))),
            None,
        );
        // The removed window may have carried the recording flag for a live
        // cast (a monitor share survives its app's window): re-resolve.
        crate::portal::service::sync_recording_meta_windows(self);
    }

    /// Tells the shell that a window is asking for the user's attention (X11
    /// `_NET_WM_STATE_DEMANDS_ATTENTION`, or a Wayland `xdg_activation_v1`
    /// request targeting an already existing window).
    ///
    /// The compositor does not focus or navigate to the window itself: the
    /// shell turns the request into a notification whose activation brings the
    /// window into view.
    pub fn notify_window_attention_requested(&mut self, meta_window_id: &str) {
        info!(meta_window_id, "window attention requested");
        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "window_attention_requested",
            Some(Box::new(json!({ "metaWindowId": meta_window_id }))),
            None,
        );
    }

    /// Tells the shell a window no longer needs attention (X11
    /// `_NET_WM_STATE_DEMANDS_ATTENTION` cleared), so it can drop the live
    /// notification it synthesized for the request.
    pub fn notify_window_attention_released(&mut self, meta_window_id: &str) {
        info!(meta_window_id, "window attention released");
        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "window_attention_released",
            Some(Box::new(json!({ "metaWindowId": meta_window_id }))),
            None,
        );
    }

    /// Tells the shell to bring a window into view after the compositor honored
    /// an activation token minted for an invoked notification action.
    ///
    /// The compositor has already focused the surface, but the shell owns the
    /// workspace and tile the window lives in: without selecting them the
    /// window stays off-screen even though it holds the keyboard focus.
    pub fn notify_window_activation_requested(&mut self, meta_window_id: &str) {
        info!(meta_window_id, "window activation requested");
        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "window_activation_requested",
            Some(Box::new(json!({ "metaWindowId": meta_window_id }))),
            None,
        );
    }

    pub fn patch_meta_window(&mut self, mut patch: MetaWindowPatch, propagate: bool) {
        match patch.clone() {
            MetaWindowPatch::UpdateAppId { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    let app_id =
                        determine_desktop_file_app_id_from_pid(meta_window.pid).or(value.clone());
                    patch = MetaWindowPatch::UpdateAppId {
                        id,
                        value: app_id.clone(),
                    };
                    meta_window.app_id = app_id;
                }
            }
            MetaWindowPatch::UpdateTitle { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.title == value.clone() {
                        return;
                    }
                    meta_window.title = value.clone();
                }
            }
            MetaWindowPatch::UpdateMapped { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.mapped == value {
                        return;
                    }
                    meta_window.mapped = value;
                }
                if value == false {
                    // An unmapped window stops rendering: there is no
                    // content a window share could keep streaming, so the
                    // session closes with a clear reason (spec 5.3).
                    crate::portal::service::close_source_share_sessions(self, &id);
                }
            }
            MetaWindowPatch::UpdateDisplayMode { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    meta_window.display_mode = value.clone();
                    // A maximized/fullscreen xdg configure must carry the size,
                    // otherwise the client reads `(0, 0)` as "choose yourself"
                    // and can fall back to its minimum size.
                    let target_size = meta_window.maximized_size();
                    let Some(wl_surface) = self.surfaces.get(&meta_window.surface_id).cloned()
                    else {
                        return;
                    };
                    let role = with_states(&wl_surface, |states| states.role);
                    match role {
                        Some(XDG_TOPLEVEL_ROLE) => {
                            if let Some(toplevel) = self.xdg_toplevels.get(&meta_window.surface_id)
                            {
                                tracing::info!(
                                    target: "veshell::geometry",
                                    meta_window_id = %id,
                                    display_mode = ?value,
                                    pending_size = ?target_size,
                                    "Sending xdg display-mode configure"
                                );
                                toplevel.with_pending_state(|state| match value {
                                    Some(DisplayMode::Maximized) => {
                                        state.states.set(xdg_toplevel::State::Maximized);
                                        state.states.unset(xdg_toplevel::State::Fullscreen);
                                        state.size = target_size;
                                    }
                                    Some(DisplayMode::Fullscreen) => {
                                        // Maximized and fullscreen share the
                                        // tile geometry; only the surface
                                        // state differs, so a client drops its
                                        // toolbars in fullscreen. Setting both
                                        // would make it read as maximized.
                                        state.states.set(xdg_toplevel::State::Fullscreen);
                                        state.states.unset(xdg_toplevel::State::Maximized);
                                        state.size = target_size;
                                    }
                                    Some(DisplayMode::Floating) => {
                                        state.states.unset(xdg_toplevel::State::Fullscreen);
                                        state.states.unset(xdg_toplevel::State::Maximized);
                                    }
                                    None => {}
                                });
                                toplevel.send_pending_configure();
                            }
                        }
                        Some(XWAYLAND_SHELL_ROLE) => {
                            if let Some(x11_surface) =
                                self.x11_surface_per_wl_surface.get(&wl_surface)
                            {
                                match value {
                                    Some(DisplayMode::Maximized) => {
                                        x11_surface
                                            .set_maximized(true)
                                            .expect("Failed to maximize window");
                                        x11_surface
                                            .set_fullscreen(false)
                                            .expect("Failed to un-fullscreen window");
                                    }
                                    Some(DisplayMode::Fullscreen) => {
                                        x11_surface
                                            .set_fullscreen(true)
                                            .expect("Failed to fullscreen window");
                                    }
                                    Some(DisplayMode::Floating) => {
                                        x11_surface
                                            .set_maximized(false)
                                            .expect("Failed to un-maximize window");
                                        x11_surface
                                            .set_fullscreen(false)
                                            .expect("Failed to un-fullscreen window");
                                    }
                                    None => {}
                                }
                            }
                        }
                        _ => {}
                    }
                }
            }
            MetaWindowPatch::UpdateWindowClass { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.window_class == value.clone() {
                        return;
                    }
                    meta_window.window_class = value.clone();
                }
            }
            MetaWindowPatch::UpdateStartupId { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.startup_id == value.clone() {
                        return;
                    }
                    meta_window.startup_id = value.clone();
                }
            }
            MetaWindowPatch::UpdateIsFixedSized { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.is_fixed_sized == value {
                        return;
                    }
                    meta_window.is_fixed_sized = value;
                }
            }
            MetaWindowPatch::UpdateIsModal { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.is_modal == value {
                        return;
                    }
                    meta_window.is_modal = value;
                }
            }
            MetaWindowPatch::UpdateIsFullscreen { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.is_fullscreen == value {
                        return;
                    }
                    meta_window.is_fullscreen = value;
                }
            }
            MetaWindowPatch::UpdateClientMaximized { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.client_maximized == value {
                        return;
                    }
                    meta_window.client_maximized = value;
                }
            }
            MetaWindowPatch::UpdateSkipTaskbar { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.skip_taskbar == value {
                        return;
                    }
                    meta_window.skip_taskbar = value;
                }
            }
            MetaWindowPatch::UpdateKeepOnTop { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.keep_on_top == value {
                        return;
                    }
                    meta_window.keep_on_top = value;
                }
            }
            MetaWindowPatch::UpdateViewport { id, value, origin } => {
                tracing::debug!(
                    target: "veshell::geometry",
                    meta_window_id = %id,
                    viewport = ?value,
                    origin = ?origin,
                    "update floating viewport"
                );
                let (should_center, should_clamp, translation) =
                    if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                        let previous_origin = meta_window.viewport_origin.clone();
                        meta_window.viewport = value;
                        meta_window.viewport_origin = origin.clone();
                        let translation = match (previous_origin, origin) {
                            (Some(previous), Some(next)) => {
                                (next.0.x - previous.0.x, next.0.y - previous.0.y)
                            }
                            _ => (0, 0),
                        };
                        let active = meta_window.is_floating() && !meta_window.client_maximized;
                        let (center, clamp) = if !active {
                            (false, false)
                        } else if meta_window.position_explicit {
                            (false, true)
                        } else {
                            (true, false)
                        };
                        (center, clamp, translation)
                    } else {
                        (false, false, (0, 0))
                    };
                if translation != (0, 0) {
                    self.translate_floating_window(&id, translation.0, translation.1);
                }
                if should_center {
                    // The shell centres a window with no explicit client
                    // placement; move the native window to the same point so a
                    // drag does not start from a different origin.
                    self.center_floating_window(&id);
                } else if should_clamp {
                    // An explicit position requested before the tile was known
                    // may be outside it; bring the native window back in.
                    self.clamp_floating_window(&id);
                }
            }
            MetaWindowPatch::UpdatePosition { id, value } => {
                if self
                    .floating_resize
                    .as_ref()
                    .is_some_and(|resize| resize.meta_window_id == id)
                {
                    // The client's configure/commit stream is behind the
                    // compositor-owned resize. Applying a stale position here
                    // makes the Flutter box snap back between resize frames.
                    return;
                }
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    let equal = match (&meta_window.position, &value) {
                        (Some(current), Some(next)) => {
                            current.0.x == next.0.x && current.0.y == next.0.y
                        }
                        (None, None) => true,
                        _ => false,
                    };
                    if equal {
                        return;
                    }
                    meta_window.position = value;
                }
            }
            MetaWindowPatch::UpdatePositionExplicit { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.position_explicit == value {
                        return;
                    }
                    meta_window.position_explicit = value;
                }
            }
            MetaWindowPatch::UpdateRenderOrigin { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    let equal = match (&meta_window.render_origin, &value) {
                        (Some(current), Some(next)) => {
                            current.0.x == next.0.x && current.0.y == next.0.y
                        }
                        (None, None) => true,
                        _ => false,
                    };
                    if equal {
                        return;
                    }
                    meta_window.render_origin = value;
                }
            }
            MetaWindowPatch::UpdateGeometry { id, value } => {
                if self
                    .floating_resize
                    .as_ref()
                    .is_some_and(|resize| resize.meta_window_id == id)
                {
                    // The native/client geometry lags the requested resize
                    // rect. Keep the compositor-published size (already in the
                    // model) until the gesture ends; otherwise each stale
                    // commit pulls the Flutter box backwards.
                    tracing::debug!(
                        target: "veshell::geometry",
                        meta_window_id = %id,
                        ignored_geometry = ?value,
                        "ignoring stale client geometry during floating resize"
                    );
                    return;
                }
                tracing::info!(
                    target: "veshell::geometry",
                    meta_window_id = %id,
                    geometry = ?value,
                    "Applying native window geometry patch"
                );
                let mut size_changed = false;
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    let are_equal = match (&meta_window.geometry, &value) {
                        (Some(current_rect), Some(new_rect)) => {
                            // Compare the numerical components only
                            current_rect.0.loc.x == new_rect.0.loc.x
                                && current_rect.0.loc.y == new_rect.0.loc.y
                                && current_rect.0.size.w == new_rect.0.size.w
                                && current_rect.0.size.h == new_rect.0.size.h
                        }
                        (None, None) => true,
                        _ => false,
                    };
                    if are_equal {
                        return;
                    }
                    // A size change moves the constraint box the window's
                    // popups are placed in; the popups must be re-constrained.
                    size_changed = meta_window.geometry.as_ref().map(|rect| rect.0.size)
                        != value.as_ref().map(|rect| rect.0.size);
                    meta_window.geometry = value.clone();
                    if propagate == false {
                        let Some(wl_surface) = self.surfaces.get(&meta_window.surface_id).cloned()
                        else {
                            return;
                        };
                        let new_size = value.as_ref().map(|rect| rect.0.size);
                        let is_floating = meta_window.is_floating();
                        let current_position = meta_window.position.clone();
                        let role = with_states(&wl_surface, |states| states.role);
                        match role {
                            Some(XDG_TOPLEVEL_ROLE) => {
                                let Some(new_size) = new_size else {
                                    return;
                                };
                                let toplevel =
                                    self.xdg_toplevels.get(&meta_window.surface_id).cloned();

                                let Some(toplevel) = toplevel else {
                                    warn!("Toplevel {} doesn't exist", meta_window.surface_id);
                                    return;
                                };
                                toplevel.with_pending_state(|state| {
                                    state.size = Some(new_size);
                                });
                                toplevel.send_configure();
                            }
                            Some(XWAYLAND_SHELL_ROLE) => {
                                let x11_surface =
                                    self.x11_surface_per_wl_surface.get(&wl_surface).cloned();

                                let Some(x11_surface) = x11_surface else {
                                    warn!("X11Surface {} doesn't exist", meta_window.surface_id);
                                    return;
                                };

                                // Geometry is surface-local. The shell owns the
                                // root position for every non-floating window;
                                // a floating window's position is changed only
                                // through SetWindowRect.
                                let mut configure = x11_surface.last_configure();
                                if let Some(new_size) = new_size {
                                    configure.size = new_size;
                                }
                                configure.loc = if is_floating {
                                    current_position
                                        .map(|position| position.0)
                                        .unwrap_or(configure.loc)
                                } else {
                                    Point::from((0, 0))
                                };
                                if let Err(err) = x11_surface.configure(configure) {
                                    warn!(
                                        meta_window_id = %id,
                                        ?err,
                                        "failed to configure surface geometry"
                                    );
                                }
                            }
                            _ => {}
                        }
                    }
                }
                if size_changed {
                    self.reconstrain_popups_for_root(&id);
                }
                // A Wayland window can publish its viewport before its first
                // committed geometry, and an X11 window can receive a
                // ConfigureNotify before the shell knows where to place it.
                // Retry the shared initial placement once the size is known;
                // this keeps both backends on the same path.
                let should_center =
                    self.meta_window_state
                        .meta_windows
                        .get(&id)
                        .is_some_and(|meta_window| {
                            meta_window.is_floating()
                                && !meta_window.client_maximized
                                && !meta_window.position_explicit
                                && meta_window.viewport.is_some()
                        });
                if should_center {
                    self.center_floating_window(&id);
                }
            }
            MetaWindowPatch::SetWindowRect {
                id,
                value,
                is_floating_mode,
            } => {
                let Some(rect) = value else {
                    return;
                };
                let Some(meta_window) = self.meta_window_state.meta_windows.get(&id).cloned()
                else {
                    return;
                };
                let floating = is_floating_mode || meta_window.is_floating();
                if !floating {
                    tracing::warn!(
                        target: "veshell::geometry",
                        meta_window_id = %id,
                        ?rect,
                        "ignoring SetWindowRect for a non-floating window"
                    );
                    return;
                }
                if rect.0.size.w <= 0 || rect.0.size.h <= 0 {
                    return;
                }
                tracing::debug!(
                    target: "veshell::geometry",
                    meta_window_id = %id,
                    ?rect,
                    is_floating_mode,
                    "set floating window rect"
                );
                // One canonical placement feeds the model, the X11 configure and
                // the Wayland configure. The client size is the requested box;
                // the geometry offset stays untouched (Wayland CSD margin).
                let placement = WindowPlacement {
                    origin: rect.0.loc,
                    client_size: rect.0.size,
                    geometry_offset: meta_window
                        .geometry
                        .as_ref()
                        .map(|geometry| geometry.0.loc)
                        .unwrap_or_else(|| Point::from((0, 0))),
                };
                let mut size_changed = false;
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    size_changed = meta_window
                        .geometry
                        .as_ref()
                        .map(|geometry| geometry.0.size)
                        != Some(placement.client_size);
                    // The shell placed the window explicitly (maximize,
                    // restore or resize), so a later viewport publication must
                    // clamp it rather than treating it as unplaced and
                    // re-centring it.
                    meta_window.position_explicit = true;
                    meta_window.position = Some(placement.origin.into());
                    let mut geometry = meta_window.geometry.clone().unwrap_or_else(|| {
                        MyRectangle(Rectangle::from_size(placement.client_size))
                    });
                    geometry.0.size = placement.client_size;
                    meta_window.geometry = Some(geometry);
                }
                let Some(wl_surface) = self.surfaces.get(&meta_window.surface_id).cloned() else {
                    return;
                };
                let role = with_states(&wl_surface, |states| states.role);
                match role {
                    Some(XDG_TOPLEVEL_ROLE) => {
                        if let Some(toplevel) =
                            self.xdg_toplevels.get(&meta_window.surface_id).cloned()
                        {
                            toplevel.with_pending_state(|state| {
                                state.size = Some(placement.client_size);
                            });
                            toplevel.send_configure();
                        }
                    }
                    Some(XWAYLAND_SHELL_ROLE) => {
                        if let Some(x11_surface) =
                            self.x11_surface_per_wl_surface.get(&wl_surface).cloned()
                        {
                            let mut configure = x11_surface.last_configure();
                            configure.loc = placement.origin;
                            configure.size = placement.client_size;
                            if let Err(err) = x11_surface.configure(configure) {
                                tracing::warn!(
                                    target: "veshell::geometry",
                                    meta_window_id = %id,
                                    ?err,
                                    "failed to configure floating window rect"
                                );
                            }
                        }
                    }
                    _ => {}
                }
                if size_changed {
                    self.reconstrain_popups_for_root(&id);
                }
            }
            MetaWindowPatch::UpdateParent { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.parent == value.clone() {
                        return;
                    }
                    meta_window.parent = value.clone();
                }
            }
            MetaWindowPatch::UpdateActivatedBy { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.activated_by == value.clone() {
                        return;
                    }
                    meta_window.activated_by = value.clone();
                }
            }
            MetaWindowPatch::UpdatePid { id, value } => {
                let mut changed = false;
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.pid == value {
                        return;
                    }
                    meta_window.pid = value;
                    changed = true;
                }
                if changed {
                    self.emit_process_info(value);
                }
            }
            MetaWindowPatch::UpdateNeedDecoration { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.need_decoration == value {
                        return;
                    }
                    meta_window.need_decoration = value;
                }
            }
            MetaWindowPatch::UpdateCurrentOutput { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.current_output == value.clone() {
                        return;
                    }
                    meta_window.current_output = value.clone();
                    let scale = value
                        .as_deref()
                        .and_then(|name| self.output_scale_for_name(name));
                    if let Some(scale) = scale {
                        self.patch_meta_window(
                            MetaWindowPatch::UpdateScaleRatio {
                                id: id,
                                value: scale,
                            },
                            true,
                        );
                    }
                }
            }
            MetaWindowPatch::UpdateGameModeActivated { id, value } => {
                let activated = {
                    let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) else {
                        return;
                    };
                    if meta_window.game_mode_activated == value {
                        return;
                    }
                    meta_window.game_mode_activated = value;
                    value.then(|| (meta_window.surface_id, meta_window.current_output.clone()))
                };
                if let Some((surface_id, current_output)) = activated {
                    self.meta_window_state.meta_window_in_gaming_mode = Some(id.clone());
                    // Flutter must not keep believing keys it was handed are
                    // held: from here they go to the client.
                    crate::keyboard::release_flutter_keys(self);
                    // Let the game pace the panel itself while it owns the
                    // output; disabled again on the way out.
                    if let Some(name) = current_output.as_deref() {
                        BackendData::set_output_vrr(self, name, true);
                    }
                    if let Some(surface) = self.surfaces.get(&surface_id).cloned() {
                        if let Some(x11_surface) =
                            self.x11_surface_per_wl_surface.get(&surface).cloned()
                        {
                            let _ = self
                                .xwayland_state
                                .as_mut()
                                .unwrap()
                                .xwm
                                .as_mut()
                                .unwrap()
                                .raise_window(&x11_surface);
                        }
                        // Enter the client at the surface's own origin, not at
                        // `(0, 0)`: a game on a monitor that does not start at
                        // the layout origin would otherwise receive pointer
                        // coordinates offset by the monitor position. The frame
                        // makes the enter/leave pair reach the client before the
                        // next event.
                        let origin = current_output
                            .as_deref()
                            .and_then(|name| {
                                self.space.outputs().find(|output| output.name() == name)
                            })
                            .and_then(|output| self.space.output_geometry(output))
                            .map(|geometry| geometry.loc.to_f64())
                            .unwrap_or_else(|| (0.0, 0.0).into());
                        self.pointer_focus = Some((PointerFocusTarget::from(&surface), origin));
                        self.refresh_pointer_focus();
                        // The compositor owns the client's focus from here until
                        // deactivation: set the keyboard focus too, so the game
                        // gets keys even though the shell's own widget focus
                        // moves (the zoom route takes it).
                        if let Err((code, message)) =
                            crate::flutter_engine::platform_channel_callbacks::activate_window::focus_surface(
                                self,
                                &surface,
                            )
                        {
                            warn!(
                                "gaming: could not focus the client keyboard: {code}: {message}"
                            );
                        }
                    }
                } else {
                    if self.meta_window_state.meta_window_in_gaming_mode.as_ref() == Some(&id) {
                        self.meta_window_state.meta_window_in_gaming_mode = None;
                    }
                    // Any keys the client was handed are released by the
                    // input path that disables the mode; this is the
                    // backstop for a deactivation that bypassed it.
                    self.game_mode_forwarded_keys.clear();
                    // The game no longer owns the pointer: clear the focus the
                    // compositor set on entry so motion stops reaching it until
                    // the shell re-establishes a focus.
                    if self.pointer_focus.take().is_some() {
                        self.refresh_pointer_focus();
                    }
                    // Give the output back to the compositor's fixed cadence.
                    if let Some(name) = self
                        .meta_window_state
                        .meta_windows
                        .get(&id)
                        .and_then(|window| window.current_output.clone())
                    {
                        BackendData::set_output_vrr(self, &name, false);
                    }
                }
                // Entering/leaving the native takeover changes what is drawn:
                // composite it now (rendering is on demand).
                self.request_render();
            }
            MetaWindowPatch::UpdateIsRecording { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.is_recording == value {
                        return;
                    }
                    meta_window.is_recording = value;
                }
            }
            MetaWindowPatch::UpdateScaleRatio { id, value } => {
                // XWayland may not be ready yet (or not be running at all):
                // then there is no client scale to mirror on x11 surfaces.
                let xwayland_scale_ratio = self
                    .xwayland_state
                    .as_ref()
                    .and_then(|state| state.client.get_data::<XWaylandClientData>())
                    .map(|data| data.compositor_state.client_scale());
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    tracing::info!(
                        target: "veshell::geometry",
                        meta_window_id = %id,
                        requested_scale_ratio = value,
                        previous_scale_ratio = meta_window.scale_ratio,
                        xwayland_scale_ratio = ?xwayland_scale_ratio,
                        "Applying native window scale patch"
                    );
                    if meta_window.scale_ratio == value {
                        return;
                    }
                    meta_window.scale_ratio = value;

                    if let Some(surface) = self.surfaces.get(&meta_window.surface_id) {
                        if let Some(x11_surface) = self.x11_surface_per_wl_surface.get(surface) {
                            // for xwayland force scale ratio to be the same as the client scale
                            if let Some(xwayland_scale_ratio) = xwayland_scale_ratio {
                                meta_window.scale_ratio = xwayland_scale_ratio;
                            }
                        } else {
                            with_states(surface, |data| {
                                with_fractional_scale(data, |fractional| {
                                    fractional.set_preferred_scale(meta_window.scale_ratio);
                                });
                            });
                        }
                    }
                }
            }
        }
        if propagate {
            let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
            platform_method_channel.invoke_method(
                "meta_window_patch",
                Some(Box::new(json!(patch))),
                None,
            );
        }
    }

    pub fn get_meta_window(&self, surface_id: u64) -> Option<MetaWindow> {
        let meta_window_id = self
            .meta_window_state
            .meta_window_id_per_surface_id
            .get(&surface_id)
            .cloned()?;

        self.meta_window_state
            .meta_windows
            .get(&meta_window_id)
            .cloned()
    }

    pub fn get_meta_popup(&self, surface_id: u64) -> Option<MetaPopup> {
        let meta_popup_id = self
            .meta_window_state
            .meta_popup_id_per_surface_id
            .get(&surface_id)
            .cloned()?;

        self.meta_window_state
            .meta_popups
            .get(&meta_popup_id)
            .cloned()
    }
}
