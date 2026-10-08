use serde::{Deserialize, Serialize};
use serde_json::json;
use smithay::{
    reexports::wayland_protocols::xdg::{
        decoration::zv1::server::zxdg_toplevel_decoration_v1::Mode as DecorationMode,
        shell::server::xdg_toplevel,
    },
    utils::{Logical, Rectangle, Size, Transform},
    wayland::{
        compositor::{send_surface_state, with_states},
        fractional_scale::with_fractional_scale,
        shell::xdg::XDG_TOPLEVEL_ROLE,
        xwayland_shell::XWAYLAND_SHELL_ROLE,
    },
    xwayland::XWaylandClientData,
};
use tracing::{info, warn};

use crate::{
    backend::Backend, flutter_engine::wayland_messages::MyRectangle, focus::PointerFocusTarget,
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
    /// `xdg_activation_v1` "opened from" relation: the surface whose activation
    /// opened this window. Only an owner hint, never a dialog trigger on its own.
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
    UpdateDisplayMode {
        id: String,
        value: Option<DisplayMode>,
    },
    UpdateMapped {
        id: String,
        value: bool,
    },
    UpdateGeometry {
        id: String,
        value: Option<MyRectangle<i32, Logical>>,
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
    /// `xdg_activation_v1` requester: the window this one was opened from. An
    /// owner hint only; unlike [`MetaWindow::parent`] it never makes the window
    /// a dialog by itself.
    pub activated_by: Option<String>,
    pub mapped: bool,
    pub display_mode: Option<DisplayMode>,
    pub title: Option<String>,
    pub window_class: Option<String>,
    pub startup_id: Option<String>,
    pub is_fixed_sized: bool,
    pub is_modal: bool,
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

impl MetaWindow {
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
        self.meta_window_state
            .meta_windows
            .remove(meta_window_id)
            .unwrap();
        // Drop it from the focus order too: a removed window can no longer be
        // the recording app's most recently focused window.
        self.meta_window_state.forget_meta_window(meta_window_id);

        // A window-share session cannot survive its window: closing the
        // MetaWindow tears the share down through the ordinary close path
        // (spec 5.3), before the removal event tells the shell the window
        // is gone. Popups of the dead window disappear from the registry
        // with it, so their surfaces stop rendering for any session.
        crate::portal::service::close_source_share_sessions(self, meta_window_id);

        if self.meta_window_state.meta_window_in_gaming_mode.as_deref()
            == Some(meta_window_id.as_str())
        {
            self.meta_window_state.meta_window_in_gaming_mode = None;
            // The client is gone; drop the keys it was holding so the next
            // gaming session starts from a clean slate.
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
            MetaWindowPatch::UpdateGeometry { id, value } => {
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
                        let role = with_states(&wl_surface, |states| states.role);
                        match role {
                            Some(XDG_TOPLEVEL_ROLE) => {
                                let toplevel =
                                    self.xdg_toplevels.get(&meta_window.surface_id).cloned();

                                let Some(toplevel) = toplevel else {
                                    warn!("Toplevel {} doesn't exist", meta_window.surface_id);
                                    return;
                                };
                                toplevel.with_pending_state(|state| {
                                    state.size = Some(value.unwrap().0.size);
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

                                x11_surface
                                    .configure(value.map(|rect| rect.into()))
                                    .unwrap();
                            }
                            _ => {}
                        }
                    }
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
                    }
                } else {
                    if self.meta_window_state.meta_window_in_gaming_mode == Some(id) {
                        self.meta_window_state.meta_window_in_gaming_mode = None;
                    }
                    // Any keys the client was handed are released by the
                    // input path that disables the mode; this is the
                    // backstop for a deactivation that bypassed it.
                    self.game_mode_forwarded_keys.clear();
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
