use std::collections::HashMap;

use meta_popup::MetaPopup;
use meta_window::{DisplayMode, MetaWindow, MetaWindowPatch};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use smithay::{
    reexports::{
        wayland_protocols::xdg::decoration::zv1::server::zxdg_toplevel_decoration_v1::Mode as DecorationMode,
        wayland_server::{DisplayHandle, Resource},
    },
    utils::{Logical, Rectangle},
    wayland::{
        compositor::with_states,
        shell::xdg::{SurfaceCachedState, ToplevelSurface, XdgToplevelSurfaceData},
    },
    xwayland::X11Surface,
};
use tracing::info;
use uuid::Uuid;

use crate::{
    backend::Backend,
    flutter_engine::{
        platform_channels::method_channel::MethodChannel,
        wayland_messages::{MyPoint, MyRectangle},
    },
    state::State,
    wayland::wayland::get_surface_id,
};

pub mod meta_popup;
pub mod meta_resize_edge;
pub mod meta_window;

pub struct MetaWindowState {
    pub meta_windows: HashMap<String, MetaWindow>,
    pub meta_window_id_per_surface_id: HashMap<u64, String>,
    pub meta_popups: HashMap<String, MetaPopup>,
    pub meta_popup_id_per_surface_id: HashMap<u64, String>,
    pub meta_window_in_gaming_mode: Option<String>,
}

impl MetaWindowState {
    pub fn new() -> MetaWindowState {
        MetaWindowState {
            meta_windows: HashMap::new(),
            meta_window_id_per_surface_id: HashMap::new(),
            meta_popups: HashMap::new(),
            meta_popup_id_per_surface_id: HashMap::new(),
            meta_window_in_gaming_mode: None,
        }
    }
}

impl<BackendData: Backend + 'static> State<BackendData> {
    pub fn new_meta_window_for_toplevel(&mut self, surface: ToplevelSurface) -> MetaWindow {
        let (title, surface_app_id, parent_surface, modal) =
            with_states(surface.wl_surface(), |surface_data| {
                let surface_state = surface_data
                    .data_map
                    .get::<XdgToplevelSurfaceData>()
                    .unwrap()
                    .lock()
                    .unwrap();
                (
                    surface_state.title.clone(),
                    surface_state.app_id.clone(),
                    surface_state.parent.clone(),
                    surface_state.modal.clone(),
                )
            });

        let geometry: Option<MyRectangle<i32, Logical>> =
            with_states(surface.wl_surface(), |surface_data| {
                surface_data
                    .cached_state
                    .get::<SurfaceCachedState>()
                    .current()
                    .geometry
                    .map(|geometry| geometry.into())
            });

        let pid = {
            let client = surface.wl_surface().client().unwrap();

            let credentials = client.get_credentials(&self.display_handle).unwrap();

            credentials.pid
        };

        let app_id = determine_desktop_file_app_id_from_pid(pid)
            .or(surface_app_id)
            .or_else(|| get_binary_name_from_pid(pid));

        let meta_window_parent = match parent_surface {
            Some(parent) => self
                .meta_window_state
                .meta_window_id_per_surface_id
                .get(&get_surface_id(&parent)),

            None => None,
        };
        let surface_id = get_surface_id(surface.wl_surface());

        let is_decorated = surface
            .current_state()
            .decoration_mode
            .map(|mode| mode == DecorationMode::ClientSide)
            .unwrap_or(true);

        let meta_window = self.create_meta_window(MetaWindow {
            id: Uuid::new_v4().hyphenated().to_string(),
            surface_id: surface_id,
            app_id: app_id.clone(),
            pid,
            parent: meta_window_parent.cloned(),
            title: title.clone(),
            mapped: false,
            display_mode: None,
            window_class: None,
            startup_id: None,
            geometry,
            need_decoration: !is_decorated,
            game_mode_activated: false,
        });
        info!("new meta window from toplevel: {:?}", meta_window);
        meta_window
    }

    pub fn new_meta_window_for_x11_surface(
        &mut self,
        x11_surface: X11Surface,
        surface_id: u64,
        parent_surface_id: Option<u64>,
    ) -> MetaWindow {
        let meta_window_parent = parent_surface_id.and_then(|parent_id| {
            self.meta_window_state
                .meta_window_id_per_surface_id
                .get(&parent_id)
        });

        let pid = x11_surface
            .get_client_pid()
            .unwrap_or_else(|_| x11_surface.pid().unwrap_or(0))
            .try_into()
            .unwrap();
        let app_id =
            determine_desktop_file_app_id_from_pid(pid).or(if !x11_surface.instance().is_empty() {
                Some(x11_surface.instance())
            } else {
                get_binary_name_from_pid(pid)
            });

        let meta_window = self.create_meta_window(MetaWindow {
            id: uuid::Uuid::new_v4().to_string(),
            surface_id: surface_id,
            app_id: app_id.clone(),
            pid,
            parent: meta_window_parent.cloned(),
            title: if !x11_surface.title().is_empty() {
                Some(x11_surface.title())
            } else {
                None
            },
            mapped: true,
            display_mode: None,
            window_class: None,
            startup_id: None,
            geometry: Some(x11_surface.geometry().into()),
            need_decoration: !x11_surface.is_decorated(),
            game_mode_activated: false,
        });
        info!("new meta window from x11: {:?}", meta_window);
        meta_window
    }
}

pub fn determine_desktop_file_app_id_from_pid(pid: i32) -> Option<String> {
    let (is_flatpack, flatpack_id) = get_flatpack_app_id_from_pid(pid);
    if is_flatpack {
        return flatpack_id;
    }

    let (is_snap, snap_id) = get_snap_app_id_from_pid(pid);
    if is_snap {
        return snap_id;
    }

    None
}

fn get_flatpack_app_id_from_pid(pid: i32) -> (bool, Option<String>) {
    if pid == 0 {
        return (false, None);
    }

    let info_filename = format!("/proc/{}/root/.flatpak-info", pid);
    let info_file = std::fs::read_to_string(info_filename);

    if info_file.is_err() {
        return (false, None);
    }

    let info_file = info_file.unwrap();
    let mut app_id: Option<String> = None;

    for line in info_file.lines() {
        if line.starts_with("name=") {
            app_id = Some(line[5..].to_string());
            break;
        }
    }

    if app_id.is_none() {
        return (false, None);
    }

    (true, app_id)
}

fn get_snap_app_id_from_pid(pid: i32) -> (bool, Option<String>) {
    if pid == 0 {
        return (false, None);
    }

    let security_label_filename = format!("/proc/{}/attr/current", pid);
    let security_label_file = std::fs::read_to_string(security_label_filename);

    if security_label_file.is_err() {
        return (false, None);
    }

    let security_label_contents = security_label_file.unwrap();
    let security_label_contents =
        security_label_contents.trim_start_matches("SNAP_SECURITY_LABEL_PREFIX");

    let contents_end_index = security_label_contents.find(' ');
    let security_label_contents = if let Some(index) = contents_end_index {
        &security_label_contents[..index]
    } else {
        security_label_contents
    };

    (true, Some(security_label_contents.replace('.', "_")))
}

fn get_binary_name_from_pid(pid: i32) -> Option<String> {
    if pid == 0 {
        return None;
    }
    // read comm and remove extension
    let comm_filename = format!("/proc/{}/comm", pid);
    let comm_file = std::fs::read_to_string(comm_filename);
    if comm_file.is_err() {
        return None;
    }
    let comm_contents = comm_file.unwrap();
    let comm_contents = comm_contents.trim_end_matches('\n');
    //let comm_contents = comm_contents.split('.').next().unwrap();
    Some(comm_contents.to_string())
}
