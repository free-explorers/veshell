use std::collections::HashMap;

use meta_popup::MetaPopup;
use meta_window::{DisplayMode, MetaWindow, MetaWindowPatch};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use smithay::{
    output::Output,
    reexports::{
        wayland_protocols::xdg::decoration::zv1::server::zxdg_toplevel_decoration_v1::Mode as DecorationMode,
        wayland_server::{DisplayHandle, Resource},
    },
    utils::{Logical, Rectangle},
    wayland::{
        compositor::with_states,
        shell::xdg::{SurfaceCachedState, ToplevelSurface, XdgToplevelSurfaceData},
    },
    xwayland::{xwm::MwmInputMode, X11Surface},
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
pub mod process_info;

pub struct MetaWindowState {
    pub meta_windows: HashMap<String, MetaWindow>,
    pub meta_window_id_per_surface_id: HashMap<u64, String>,
    pub meta_popups: HashMap<String, MetaPopup>,
    pub meta_popup_id_per_surface_id: HashMap<u64, String>,
    pub meta_window_in_gaming_mode: Option<String>,
    /// `xdg_activation_v1` requesters (see `State::request_activation`) for
    /// surfaces whose meta window does not exist yet. Consumed in
    /// [`Self::new_meta_window_for_toplevel`] so the relation is available as
    /// [`MetaWindow::activated_by`] before the window is mapped.
    pub pending_activation_parent: HashMap<u64, String>,
}

impl MetaWindowState {
    pub fn new() -> MetaWindowState {
        MetaWindowState {
            meta_windows: HashMap::new(),
            meta_window_id_per_surface_id: HashMap::new(),
            meta_popups: HashMap::new(),
            meta_popup_id_per_surface_id: HashMap::new(),
            meta_window_in_gaming_mode: None,
            pending_activation_parent: HashMap::new(),
        }
    }

    /// Windows whose `current_output` is the given output.
    ///
    /// Output identity is the connector name (`Output::name()`, also
    /// `Monitor.name` in the shell). It is the same value the shell writes back
    /// through `MetaWindowPatch::UpdateCurrentOutput`, so a lookup here matches
    /// the placement the shell reported. The connector name survives a
    /// disconnect/reconnect of the same monitor.
    pub fn get_meta_windows_for_output(&mut self, output: Output) -> Vec<MetaWindow> {
        let mut meta_windows = Vec::new();
        let some_name = Some(output.name());
        for (_, meta_window) in self.meta_windows.iter_mut() {
            if meta_window.current_output == some_name {
                meta_windows.push(meta_window.clone());
            }
        }
        meta_windows
    }
}

impl<BackendData: Backend + 'static> State<BackendData> {
    /// Sends the process-level facts (`cgroup`, Flatpak/Snap id, binary name)
    /// of `pid` to the shell.
    ///
    /// Emitted when a window first reports a pid, when the pid changes, and
    /// again when the window is mapped, so the shell's pid table follows the
    /// process as it re-homes into its final cgroup.
    pub fn emit_process_info(&mut self, pid: i32) {
        let info = process_info::ProcessInfo::for_pid(pid);
        tracing::debug!(target: "veshell::process_info", ?info, "emitting process info");
        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method("process_info", Some(Box::new(json!(info))), None);
    }

    /// Fractional scale of the connected output named `name`.
    ///
    /// This is the single output-scale lookup. `name` is the connector name
    /// (`Output::name()`), which is what `MetaWindow::current_output` stores and
    /// what the shell reports back as `updateCurrentOutput`.
    pub fn output_scale_for_name(&self, name: &str) -> Option<f64> {
        self.space
            .outputs()
            .find(|output| output.name() == name)
            .map(|output| output.current_scale().fractional_scale())
    }

    /// Preferred scale for a meta window that has no `current_output` yet.
    ///
    /// Window placement is owned by the shell, so at creation time Rust cannot
    /// know which monitor a window will land on: the shell only reports it
    /// after rendering the window, which then drives the `UpdateScaleRatio`
    /// round-trip. Until that happens the window is given the scale of the
    /// output under the pointer, falling back to the first connected output.
    /// A native client therefore never starts at the implicit 1.0 on a scaled
    /// monitor; `UpdateScaleRatio` replaces this value as soon as the real
    /// output is known.
    ///
    /// This is also the documented "no current output" default: unplaced
    /// windows are assumed to open on the monitor the user is interacting with.
    pub fn fallback_scale_ratio(&self) -> f64 {
        self.space
            .output_under(self.pointer.current_location())
            .next()
            .or_else(|| self.space.outputs().next())
            .map(|output| output.current_scale().fractional_scale())
            .unwrap_or(1.0)
    }

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
                    matches!(
                        surface_state.dialog_hint,
                        smithay::wayland::shell::xdg::dialog::ToplevelDialogHint::Modal
                    ),
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

        let surface_id = get_surface_id(surface.wl_surface());

        // An activation relation discovered before this toplevel had a meta
        // window (the common case: the client activates the window it is about
        // to map). It is recorded as `activated_by`, independently of any
        // client-declared `xdg_toplevel.set_parent`.
        let activation_parent = self
            .meta_window_state
            .pending_activation_parent
            .remove(&surface_id);

        let xdg_parent = match parent_surface {
            Some(parent) => self
                .meta_window_state
                .meta_window_id_per_surface_id
                .get(&get_surface_id(&parent))
                .cloned(),

            None => None,
        };

        // A client-declared parent and an activation "opened from" hint are
        // independent signals and are recorded separately.
        let meta_window_parent = xdg_parent;
        let activated_by = activation_parent;

        let is_decorated = surface.with_cached_state(|state| {
            state
                .last_acked
                .as_ref()
                .and_then(|configure| configure.state.decoration_mode)
                .map(|mode| mode == DecorationMode::ClientSide)
                .unwrap_or(true)
        });

        self.emit_process_info(pid);

        // Placement is the shell's call, so the real output is not known yet;
        // seed the client scale from the output under the pointer. See
        // `State::fallback_scale_ratio`.
        let fallback_scale_ratio = self.fallback_scale_ratio();

        let meta_window = self.create_meta_window(MetaWindow {
            id: Uuid::new_v4().hyphenated().to_string(),
            surface_id: surface_id,
            app_id: app_id.clone(),
            pid,
            parent: meta_window_parent,
            activated_by,
            title: title.clone(),
            mapped: false,
            display_mode: None,
            window_class: None,
            startup_id: None,
            is_fixed_sized: false,
            is_modal: modal,
            geometry,
            current_output: None,
            need_decoration: !is_decorated,
            scale_ratio: fallback_scale_ratio,
            game_mode_activated: false,
        });
        info!(
            target: "veshell::geometry",
            surface_id,
            meta_window_id = %meta_window.id,
            geometry = ?meta_window.geometry,
            scale_ratio = meta_window.scale_ratio,
            mapped = meta_window.mapped,
            "Created toplevel window geometry"
        );
        info!("new meta window from toplevel: {:?}", meta_window);
        meta_window
    }

    /// Creates the meta window for an XWayland surface.
    ///
    /// `scale_ratio` is the XWayland compositor's global client scale, not the
    /// output scale. X11 clients have no per-surface fractional scale, so their
    /// X surfaces are forced to this value (`UpdateScaleRatio` overwrites any
    /// requested scale with it); this is intentional, not a bug.
    pub fn new_meta_window_for_x11_surface(
        &mut self,
        x11_surface: X11Surface,
        surface_id: u64,
        parent_surface_id: Option<u64>,
        scale_ratio: f64,
    ) -> MetaWindow {
        let meta_window_parent = parent_surface_id.and_then(|parent_id| {
            self.meta_window_state
                .meta_window_id_per_surface_id
                .get(&parent_id)
                .cloned()
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

        self.emit_process_info(pid);

        let meta_window = self.create_meta_window(MetaWindow {
            id: uuid::Uuid::new_v4().to_string(),
            surface_id: surface_id,
            app_id: app_id.clone(),
            pid,
            parent: meta_window_parent,
            activated_by: None,
            title: if !x11_surface.title().is_empty() {
                Some(x11_surface.title())
            } else {
                None
            },
            mapped: true,
            display_mode: None,
            window_class: (!x11_surface.class().is_empty()).then(|| x11_surface.class()),
            startup_id: x11_surface.startup_id(),
            is_fixed_sized: x11_is_fixed_sized(&x11_surface),
            is_modal: x11_is_modal(&x11_surface),
            current_output: None,
            geometry: Some(x11_surface.geometry().into()),
            need_decoration: !x11_surface.is_decorated(),
            scale_ratio: scale_ratio,
            game_mode_activated: false,
        });
        info!("new meta window from x11: {:?}", meta_window);
        meta_window
    }
}

/// Whether an X11 window is modal, from `_NET_WM_STATE_MODAL` or its MOTIF
/// input mode. The X11 counterpart of the `xdg_wm_dialog_v1` modal hint.
pub(crate) fn x11_is_modal(x11_surface: &X11Surface) -> bool {
    x11_surface.is_modal()
        || matches!(
            x11_surface.motif_hints().input_mode,
            Some(MwmInputMode::PrimaryApplicationModal)
                | Some(MwmInputMode::SystemModal)
                | Some(MwmInputMode::FullApplicationModal)
        )
}

/// Whether an X11 window is fixed-size: both axes constrained to the same
/// non-zero size, the X11 counterpart of the Wayland `min == max` check.
pub(crate) fn x11_is_fixed_sized(x11_surface: &X11Surface) -> bool {
    x11_surface
        .min_size()
        .zip(x11_surface.max_size())
        .is_some_and(|(min, max)| min.w > 0 && min.h > 0 && min == max)
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

pub(crate) fn get_flatpack_app_id_from_pid(pid: i32) -> (bool, Option<String>) {
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

pub(crate) fn get_snap_app_id_from_pid(pid: i32) -> (bool, Option<String>) {
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

pub(crate) fn get_binary_name_from_pid(pid: i32) -> Option<String> {
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
