use serde::{Deserialize, Serialize};
use serde_json::json;
use smithay::{
    reexports::wayland_protocols::xdg::{
        decoration::zv1::server::zxdg_toplevel_decoration_v1::Mode as DecorationMode,
        shell::server::xdg_toplevel,
    },
    utils::{Logical, Rectangle},
    wayland::{
        compositor::with_states, shell::xdg::XDG_TOPLEVEL_ROLE, xwayland_shell::XWAYLAND_SHELL_ROLE,
    },
};
use tracing::warn;

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
    UpdateParent {
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
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(rename_all = "camelCase")]
pub struct MetaWindow {
    pub id: String,
    pub app_id: Option<String>,
    pub pid: i32,
    pub surface_id: u64,
    pub parent: Option<String>,
    pub mapped: bool,
    pub display_mode: Option<DisplayMode>,
    pub title: Option<String>,
    pub window_class: Option<String>,
    pub startup_id: Option<String>,
    pub geometry: Option<MyRectangle<i32, Logical>>,
    pub need_decoration: bool,
    pub game_mode_activated: bool,
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
        meta_window
    }

    pub fn remove_meta_window(&mut self, meta_window_id: &String) {
        self.meta_window_state
            .meta_windows
            .remove(meta_window_id)
            .unwrap();

        if self.meta_window_state.meta_window_in_gaming_mode == Some(meta_window_id.clone()) {
            self.meta_window_state.meta_window_in_gaming_mode = None;
        }

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "meta_window_removed",
            Some(Box::new(json!({
                "id": meta_window_id.clone(),
            }))),
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
                    if meta_window.mapped == value.clone() {
                        return;
                    }
                    meta_window.mapped = value.clone();
                }
            }
            MetaWindowPatch::UpdateDisplayMode { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    meta_window.display_mode = value.clone();
                    let Some(wl_surface) = self.surfaces.get(&meta_window.surface_id).cloned()
                    else {
                        return;
                    };
                    let role = with_states(&wl_surface, |states| states.role);
                    match role {
                        Some(XDG_TOPLEVEL_ROLE) => {
                            if let Some(toplevel) = self.xdg_toplevels.get(&meta_window.surface_id)
                            {
                                toplevel.with_pending_state(|state| match value {
                                    Some(DisplayMode::Maximized) => {
                                        state.states.set(xdg_toplevel::State::Maximized);
                                        state.states.unset(xdg_toplevel::State::Fullscreen);
                                    }
                                    Some(DisplayMode::Fullscreen) => {
                                        state.states.set(xdg_toplevel::State::Fullscreen);
                                        state.states.set(xdg_toplevel::State::Maximized);
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
            MetaWindowPatch::UpdateGeometry { id, value } => {
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
            }
            MetaWindowPatch::UpdateParent { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.parent == value.clone() {
                        return;
                    }
                    meta_window.parent = value.clone();
                }
            }
            MetaWindowPatch::UpdatePid { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.pid == value.clone() {
                        return;
                    }
                    meta_window.pid = value.clone();
                }
            }
            MetaWindowPatch::UpdateNeedDecoration { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.need_decoration == value.clone() {
                        return;
                    }
                    meta_window.need_decoration = value.clone();
                }
            }
            MetaWindowPatch::UpdateGameModeActivated { id, value } => {
                if let Some(meta_window) = self.meta_window_state.meta_windows.get_mut(&id) {
                    if meta_window.game_mode_activated == value.clone() {
                        return;
                    }
                    meta_window.game_mode_activated = value.clone();
                    if value {
                        self.meta_window_state.meta_window_in_gaming_mode = Some(id);

                        if let Some(surface) = self.surfaces.get(&meta_window.surface_id) {
                            if let Some(x11_surface) =
                                self.x11_surface_per_wl_surface.get(surface).cloned()
                            {
                                let _ = self.x11_wm.as_mut().unwrap().raise_window(&x11_surface);
                            }
                            self.pointer_focus =
                                Some((PointerFocusTarget::from(surface), (0.0, 0.0).into()));
                        }
                    } else {
                        if self.meta_window_state.meta_window_in_gaming_mode == Some(id) {
                            self.meta_window_state.meta_window_in_gaming_mode = None;
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
