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
    utils::{Logical, Point, Rectangle},
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

pub mod floating_move;
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
    /// MetaWindow ids ordered by focus recency, least recent first. Updated
    /// whenever the shell activates a window (`activate_window`), so the
    /// recording indicator's app-id fallback can pick an app's most recently
    /// focused window instead of guessing from the layout.
    pub focus_order: Vec<String>,
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
            focus_order: Vec::new(),
            pending_activation_parent: HashMap::new(),
        }
    }

    /// The compositor-global origin of the tile content area that owns a
    /// window.
    ///
    /// The tile popup host publishes this for every display mode. Floating
    /// windows fall back to their measured viewport origin, and tiled windows
    /// to their rendered surface origin, so popups can be normalized before
    /// the first host frame completes.
    pub fn tile_content_origin(&self, meta_window_id: &str) -> Option<Point<i32, Logical>> {
        let meta_window = self.meta_windows.get(meta_window_id)?;
        meta_window
            .tile_origin
            .as_ref()
            .map(|origin| origin.0)
            .or_else(|| {
                if meta_window.is_floating() {
                    meta_window
                        .viewport_origin
                        .as_ref()
                        .map(|origin| origin.0)
                        .or_else(|| meta_window.position.as_ref().map(|position| position.0))
                } else {
                    meta_window
                        .render_origin
                        .as_ref()
                        .map(|origin| origin.0)
                        .or_else(|| meta_window.position.as_ref().map(|position| position.0))
                }
            })
    }

    /// The compositor-global origin of a window's client surface.
    ///
    /// A floating window's native surface is authoritative; a tiled window
    /// uses the origin rendered by Flutter because its native X11 position can
    /// be synthetic.
    pub fn meta_window_surface_origin(&self, meta_window_id: &str) -> Option<Point<f64, Logical>> {
        let meta_window = self.meta_windows.get(meta_window_id)?;
        if meta_window.is_floating() {
            meta_window.surface_origin().or_else(|| {
                meta_window
                    .render_origin
                    .as_ref()
                    .map(|origin| Point::from((f64::from(origin.0.x), f64::from(origin.0.y))))
            })
        } else {
            meta_window
                .render_origin
                .as_ref()
                .map(|origin| Point::from((f64::from(origin.0.x), f64::from(origin.0.y))))
                .or_else(|| meta_window.surface_origin())
        }
    }

    /// The owning tile-relative origin of a window's client box.
    ///
    /// Wayland xdg popups report coordinates relative to the parent window
    /// box, not its surface buffer. A floating window already stores that box
    /// origin in `position`; a tiled window derives it from Flutter's surface
    /// render origin plus the surface-local geometry offset.
    pub fn meta_window_box_tile_origin(&self, meta_window_id: &str) -> Option<Point<i32, Logical>> {
        let tile_origin = self.tile_content_origin(meta_window_id)?;
        let meta_window = self.meta_windows.get(meta_window_id)?;
        let global_box_origin = if meta_window.is_floating() {
            meta_window
                .position
                .as_ref()
                .map(|position| position.0)
                .or_else(|| {
                    meta_window.render_origin.as_ref().map(|origin| {
                        let geometry_offset = meta_window
                            .geometry
                            .as_ref()
                            .map(|geometry| geometry.0.loc)
                            .unwrap_or_else(|| Point::from((0, 0)));
                        Point::from((
                            origin.0.x + geometry_offset.x,
                            origin.0.y + geometry_offset.y,
                        ))
                    })
                })?
        } else {
            meta_window
                .render_origin
                .as_ref()
                .map(|origin| {
                    let geometry_offset = meta_window
                        .geometry
                        .as_ref()
                        .map(|geometry| geometry.0.loc)
                        .unwrap_or_else(|| Point::from((0, 0)));
                    Point::from((
                        origin.0.x + geometry_offset.x,
                        origin.0.y + geometry_offset.y,
                    ))
                })
                .or_else(|| meta_window.position.as_ref().map(|position| position.0))?
        };
        Some(Point::from((
            global_box_origin.x - tile_origin.x,
            global_box_origin.y - tile_origin.y,
        )))
    }

    /// Convert a position that is relative to a parent window's client box
    /// into the owning tile's content coordinates.
    ///
    /// Wayland xdg popups report parent-box-relative coordinates. The shared
    /// popup model stores tile-relative coordinates; this boundary conversion
    /// keeps the protocol-specific space out of the renderer.
    pub fn popup_tile_position(
        &self,
        parent_meta_window_id: &str,
        parent_relative: Point<i32, Logical>,
    ) -> Option<Point<i32, Logical>> {
        let parent_tile_origin = self.meta_window_box_tile_origin(parent_meta_window_id)?;
        Some(Point::from((
            parent_tile_origin.x + parent_relative.x,
            parent_tile_origin.y + parent_relative.y,
        )))
    }

    /// Convert an X11 override-redirect popup's root position to the owning
    /// tile's content coordinates.
    ///
    /// X11 popups are independent top-level windows reported in root
    /// coordinates, but the parent's native root is not the parent's rendered
    /// origin for a tiled window (the X11 adapter deliberately keeps tiled
    /// parents at root `(0,0)`). Subtract the parent's native root first, then
    /// use the shared parent-box conversion.
    pub fn x11_popup_tile_position(
        &self,
        parent_meta_window_id: &str,
        popup_root: Point<i32, Logical>,
    ) -> Option<Point<i32, Logical>> {
        let parent = self.meta_windows.get(parent_meta_window_id)?;
        let parent_root = parent.position.as_ref()?.0;
        let parent_relative =
            Point::from((popup_root.x - parent_root.x, popup_root.y - parent_root.y));
        self.popup_tile_position(parent_meta_window_id, parent_relative)
    }

    /// The compositor-global origin of a popup's client surface.
    ///
    /// Popup positions are stored relative to the owning tile's content
    /// origin. The tile origin is the anchor, so moving the tile moves the
    /// popup while moving its parent window does not.
    pub fn popup_surface_origin(&self, popup: &MetaPopup) -> Option<Point<f64, Logical>> {
        let tile_origin = self.tile_content_origin(&popup.parent)?;
        let surface_origin = popup.placement().surface_origin();
        Some(Point::from((
            f64::from(tile_origin.x) + surface_origin.x,
            f64::from(tile_origin.y) + surface_origin.y,
        )))
    }

    /// Records `id` as the most recently focused MetaWindow.
    ///
    /// Called from `activate_window`: the shell is the compositor's focus
    /// source, so this is the trusted focus order. Re-focusing a window moves
    /// it to the front rather than duplicating it.
    pub fn record_meta_window_focus(&mut self, id: &str) {
        self.focus_order.retain(|existing| existing != id);
        self.focus_order.push(id.to_string());
    }

    /// Forgets a removed MetaWindow so it can no longer be resolved as the
    /// focus target of a live cast.
    pub fn forget_meta_window(&mut self, id: &str) {
        self.focus_order.retain(|existing| existing != id);
    }

    /// The most recently focused MetaWindow satisfying `predicate`, falling
    /// back to any match when no focused window qualifies (for example a cast
    /// that started before the app was ever focused).
    fn most_recent_meta_window_where(
        &self,
        predicate: impl Fn(&MetaWindow) -> bool,
    ) -> Option<String> {
        self.focus_order
            .iter()
            .rev()
            .find(|id| {
                self.meta_windows
                    .get(*id)
                    .is_some_and(|window| predicate(window))
            })
            .cloned()
            .or_else(|| {
                self.meta_windows
                    .values()
                    .find(|window| predicate(window))
                    .map(|window| window.id.clone())
            })
    }

    /// The MetaWindow a live screen cast should mark as recording.
    ///
    /// Resolution is layered, least heuristic first (capture review):
    /// 1. the compositor-observed consumer pid, matched against
    ///    [`MetaWindow::pid`];
    /// 2. the portal `app_id`, then the consumer node's self-reported identity
    ///    ([`MetaWindow::app_id`] or [`MetaWindow::binary_name`]), resolved to
    ///    the app's most recently focused window.
    ///
    /// Returns `None` when neither identity maps to a window: the indicator
    /// then has no tile to live on rather than guessing one.
    pub fn recording_meta_window_for(
        &self,
        app_id: &str,
        consumer_app_id: Option<&str>,
        consumer_pid: Option<i32>,
    ) -> Option<String> {
        if let Some(pid) = consumer_pid {
            if let Some(id) = self.most_recent_meta_window_where(|window| window.pid == pid) {
                return Some(id);
            }
        }
        for hint in [app_id, consumer_app_id.unwrap_or("")] {
            if hint.is_empty() {
                continue;
            }
            if let Some(id) = self
                .most_recent_meta_window_where(|window| meta_window_matches_app_hint(window, hint))
            {
                return Some(id);
            }
        }
        None
    }

    /// The MetaWindow an external dialog request (for example the FileChooser
    /// portal) should be shown above: the requesting app's most recently
    /// focused window, or any matching window when the app was never focused.
    ///
    /// Returns `None` when the identity maps to no window, so the shell falls
    /// back to the focused monitor rather than guessing.
    pub fn requester_meta_window_for(&self, app_id: &str) -> Option<String> {
        self.recording_meta_window_for(app_id, None, None)
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

    /// Ids of the windows in gaming mode placed on the output named
    /// `output_name`.
    ///
    /// A game surface belongs to the output its tile was placed on: rendering it
    /// on every output would duplicate the game on the other monitors.
    pub fn game_mode_window_ids_for_output(&self, output_name: &str) -> Vec<String> {
        self.meta_windows
            .values()
            .filter(|meta_window| {
                meta_window.game_mode_activated
                    && meta_window.current_output.as_deref() == Some(output_name)
            })
            .map(|meta_window| meta_window.id.clone())
            .collect()
    }
}

impl<BackendData: Backend + 'static> State<BackendData> {
    /// Surfaces of the windows in gaming mode on the output named `output_name`.
    ///
    /// A game surface belongs to the output its tile was placed on: rendering it
    /// on every output would duplicate the game on the other monitors. The
    /// surfaces are cloned out so a caller can take `&mut self` afterwards (the
    /// capture path renders through the backend).
    pub fn game_mode_surfaces_for_output(
        &self,
        output_name: &str,
    ) -> Vec<smithay::reexports::wayland_server::protocol::wl_surface::WlSurface> {
        self.meta_window_state
            .game_mode_window_ids_for_output(output_name)
            .into_iter()
            .filter_map(|id| {
                self.meta_window_state
                    .meta_windows
                    .get(&id)
                    .and_then(|meta_window| self.surfaces.get(&meta_window.surface_id).cloned())
            })
            .collect()
    }
}

/// Whether two app ids name the same application.
///
/// The portal `app_id` is client-supplied while [`MetaWindow::app_id`] may be
/// a desktop-file id, a Flatpak/Snap id or a binary name, so compare with a
/// `.desktop` suffix stripped and case-insensitively. This normalizes spelling
/// only; it never guesses across different names.
fn app_ids_match(left: &str, right: &str) -> bool {
    fn normalize(id: &str) -> &str {
        id.strip_suffix(".desktop").unwrap_or(id)
    }
    normalize(left).eq_ignore_ascii_case(normalize(right))
}

/// Whether a window's identity matches an app id / PipeWire node hint.
///
/// Matches the window's app id (spelling-normalized) or its process binary
/// name: the portal frontend proxies the stream, so the consumer pid is the
/// portal's and the cast is often named only by the node the client created
/// (`node.name=brave`), which is the binary name while the window's app id is
/// `brave-browser`.
fn meta_window_matches_app_hint(window: &MetaWindow, hint: &str) -> bool {
    window
        .app_id
        .as_deref()
        .is_some_and(|id| app_ids_match(id, hint))
        || window
            .binary_name
            .as_deref()
            .is_some_and(|name| name.eq_ignore_ascii_case(hint))
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

        let binary_name = get_binary_name_from_pid(pid);
        let app_id = determine_desktop_file_app_id_from_pid(pid)
            .or(surface_app_id)
            .or_else(|| binary_name.clone());

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
            binary_name: binary_name.clone(),
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
            is_fullscreen: false,
            client_maximized: false,
            skip_taskbar: false,
            keep_on_top: false,
            position: None,
            position_explicit: false,
            render_origin: None,
            viewport: None,
            viewport_origin: None,
            tile_origin: None,
            geometry,
            current_output: None,
            need_decoration: !is_decorated,
            scale_ratio: fallback_scale_ratio,
            game_mode_activated: false,
            is_recording: false,
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
        let binary_name = get_binary_name_from_pid(pid);
        let app_id =
            determine_desktop_file_app_id_from_pid(pid).or(if !x11_surface.instance().is_empty() {
                Some(x11_surface.instance())
            } else {
                binary_name.clone()
            });

        let position = x11_surface
            .size_hints()
            .and_then(|hints| hints.position)
            .map(|(_, x, y)| Point::from((x, y)).into())
            .or_else(|| Some(x11_surface.last_configure().loc.into()));

        self.emit_process_info(pid);

        let meta_window = self.create_meta_window(MetaWindow {
            id: uuid::Uuid::new_v4().to_string(),
            surface_id: surface_id,
            app_id: app_id.clone(),
            binary_name: binary_name.clone(),
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
            is_fullscreen: x11_surface.is_fullscreen(),
            client_maximized: false,
            skip_taskbar: x11_surface.is_skip_taskbar(),
            keep_on_top: x11_surface.is_above(),
            position,
            position_explicit: false,
            render_origin: None,
            viewport: None,
            viewport_origin: None,
            tile_origin: None,
            current_output: None,
            geometry: Some(x11_surface.geometry().into()),
            need_decoration: !x11_surface.is_decorated(),
            scale_ratio: scale_ratio,
            game_mode_activated: false,
            is_recording: false,
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

/// snapd prefixes every confined snap's AppArmor label with this. It is also
/// what tells a snap apart from an SELinux system: `/proc/<pid>/attr/current`
/// holds a label for *every* process under SELinux, but its context (e.g.
/// `unconfined_u:unconfined_r:unconfined_t:s0`) never starts with `snap.`.
const SNAP_SECURITY_LABEL_PREFIX: &str = "snap.";

/// Parses the snap application id out of an AppArmor security label, or `None`
/// when the label does not belong to a snap.
///
/// AppArmor reports a snap's label as `snap.<snap>.<app> (enforce)` (or
/// `(complain)`); the id is the part before the ` (mode)` suffix with the dots
/// replaced by underscores. Anything else — an SELinux context, an unconfined
/// or non-snap AppArmor profile — yields `None`, which is what keeps the
/// process-based desktop-file lookup from misidentifying non-snap processes on
/// SELinux distributions.
fn snap_app_id_from_security_label(security_label: &str) -> Option<String> {
    let security_label = security_label.trim_end_matches(['\0', '\n']);
    let snap = security_label.strip_prefix(SNAP_SECURITY_LABEL_PREFIX)?;
    Some(snap.split(' ').next().unwrap_or(snap).replace('.', "_"))
}

pub(crate) fn get_snap_app_id_from_pid(pid: i32) -> (bool, Option<String>) {
    if pid == 0 {
        return (false, None);
    }

    let security_label_filename = format!("/proc/{}/attr/current", pid);
    let Ok(security_label) = std::fs::read_to_string(security_label_filename) else {
        return (false, None);
    };

    match snap_app_id_from_security_label(&security_label) {
        Some(snap_id) => (true, Some(snap_id)),
        None => (false, None),
    }
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

#[cfg(test)]
mod tests {
    use super::meta_popup::MetaPopupCategory;
    use super::*;

    fn window(id: &str, pid: i32, app_id: Option<&str>) -> MetaWindow {
        MetaWindow {
            id: id.to_string(),
            app_id: app_id.map(str::to_string),
            binary_name: None,
            pid,
            surface_id: 0,
            parent: None,
            activated_by: None,
            mapped: true,
            display_mode: None,
            title: None,
            window_class: None,
            startup_id: None,
            is_fixed_sized: false,
            is_modal: false,
            is_fullscreen: false,
            client_maximized: false,
            skip_taskbar: false,
            keep_on_top: false,
            position: None,
            position_explicit: false,
            render_origin: None,
            viewport: None,
            viewport_origin: None,
            tile_origin: None,
            geometry: None,
            need_decoration: false,
            current_output: None,
            scale_ratio: 1.0,
            game_mode_activated: false,
            is_recording: false,
        }
    }

    fn state_with(windows: Vec<MetaWindow>, focus: &[&str]) -> MetaWindowState {
        let mut state = MetaWindowState::new();
        for window in windows {
            state.meta_windows.insert(window.id.clone(), window);
        }
        for id in focus {
            state.record_meta_window_focus(id);
        }
        state
    }

    #[test]
    fn wayland_popup_position_uses_the_parent_box_not_the_surface() {
        let mut parent = window("parent", 1, Some("org.example.Parent"));
        parent.display_mode = Some(DisplayMode::Floating);
        parent.position = Some(Point::from((48, 30)).into());
        parent.tile_origin = Some(Point::from((48, 48)).into());
        parent.geometry = Some(Rectangle::new((24, 21).into(), (2512, 1392).into()).into());
        let state = state_with(vec![parent], &[]);

        assert_eq!(
            state.popup_tile_position("parent", Point::from((550, 66))),
            Some(Point::from((550, 48)))
        );
    }

    #[test]
    fn popup_origin_uses_the_tile_origin() {
        let mut parent = window("parent", 1, Some("org.example.Parent"));
        parent.tile_origin = Some(Point::from((100, 200)).into());
        let state = state_with(vec![parent], &[]);
        let popup = MetaPopup {
            id: "popup".to_string(),
            parent: "parent".to_string(),
            category: MetaPopupCategory::Popup,
            position: Point::from((30, 40)).into(),
            native_root: None,
            parent_relative: None,
            geometry: Some(Rectangle::new((10, 10).into(), (100, 100).into()).into()),
            surface_id: 0,
            scale_ratio: 1.0,
        };

        assert_eq!(
            state.popup_surface_origin(&popup),
            Some(Point::from((120.0, 230.0)))
        );
    }

    #[test]
    fn x11_popup_position_uses_the_parent_native_root() {
        let mut tiled_parent = window("tiled-parent", 1, Some("org.example.Parent"));
        tiled_parent.display_mode = Some(DisplayMode::Maximized);
        // Tiled X11 windows deliberately keep their native root at (0,0)
        // while Flutter renders them at the tile origin.
        tiled_parent.position = Some(Point::from((0, 0)).into());
        tiled_parent.render_origin = Some(Point::from((1000, 100)).into());
        tiled_parent.tile_origin = Some(Point::from((1000, 100)).into());
        tiled_parent.geometry =
            Some(Rectangle::new((0, 0).into(), smithay::utils::Size::from((800, 600))).into());
        let state = state_with(vec![tiled_parent], &[]);

        assert_eq!(
            state.x11_popup_tile_position("tiled-parent", Point::from((100, 80))),
            Some(Point::from((100, 80)))
        );

        let mut floating_parent = window("floating-parent", 1, Some("org.example.Parent"));
        floating_parent.display_mode = Some(DisplayMode::Floating);
        floating_parent.position = Some(Point::from((1000, 100)).into());
        floating_parent.tile_origin = Some(Point::from((1000, 100)).into());
        floating_parent.geometry =
            Some(Rectangle::new((0, 0).into(), smithay::utils::Size::from((800, 600))).into());
        let state = state_with(vec![floating_parent], &[]);

        assert_eq!(
            state.x11_popup_tile_position("floating-parent", Point::from((1100, 180))),
            Some(Point::from((100, 80)))
        );
    }

    #[test]
    fn popup_origin_uses_the_parent_render_origin_as_a_fallback() {
        let mut parent = window("parent", 1, Some("org.example.Parent"));
        parent.render_origin = Some(Point::from((700, 120)).into());
        let state = state_with(vec![parent], &[]);
        let popup = MetaPopup {
            id: "popup".to_string(),
            parent: "parent".to_string(),
            category: MetaPopupCategory::Popup,
            position: Point::from((30, 40)).into(),
            native_root: None,
            parent_relative: None,
            geometry: Some(Rectangle::new((10, 10).into(), (100, 100).into()).into()),
            surface_id: 0,
            scale_ratio: 1.0,
        };

        assert_eq!(
            state.popup_surface_origin(&popup),
            Some(Point::from((720.0, 150.0)))
        );

        let without_render_origin =
            state_with(vec![window("parent", 1, Some("org.example.Parent"))], &[]);
        assert_eq!(without_render_origin.popup_surface_origin(&popup), None);

        let mut floating_parent = window("parent", 1, Some("org.example.Parent"));
        floating_parent.display_mode = Some(DisplayMode::Floating);
        floating_parent.position = Some(Point::from((48, 88)).into());
        floating_parent.render_origin = Some(Point::from((961, 644)).into());
        let floating_state = state_with(vec![floating_parent], &[]);
        assert_eq!(
            floating_state.popup_surface_origin(&popup),
            Some(Point::from((68.0, 118.0)))
        );
    }

    #[test]
    fn decorated_floating_windows_use_the_compositor_resize_path() {
        let mut floating = window("floating", 1, Some("org.example.Floating"));
        floating.display_mode = Some(DisplayMode::Floating);
        floating.need_decoration = true;
        assert!(
            crate::meta_window_state::floating_move::can_resize_floating(
                &floating,
                crate::meta_window_state::meta_resize_edge::MetaResizeEdge::BOTTOM_RIGHT,
            )
        );

        floating.is_fixed_sized = true;
        assert!(
            !crate::meta_window_state::floating_move::can_resize_floating(
                &floating,
                crate::meta_window_state::meta_resize_edge::MetaResizeEdge::BOTTOM_RIGHT,
            )
        );
    }

    #[test]
    fn interactive_resize_is_limited_to_floating_windows_and_dialogs() {
        let mut tiled = window("tiled", 1, Some("org.example.Tiled"));
        tiled.display_mode = Some(DisplayMode::Maximized);
        assert!(!tiled.allows_interactive_resize());

        let mut floating = window("floating", 1, Some("org.example.Floating"));
        floating.display_mode = Some(DisplayMode::Floating);
        assert!(floating.allows_interactive_resize());

        let mut parented = window("parented", 1, Some("org.example.Dialog"));
        parented.parent = Some("owner".to_string());
        assert!(parented.allows_interactive_resize());

        let mut modal = window("modal", 1, Some("org.example.Dialog"));
        modal.is_modal = true;
        assert!(modal.allows_interactive_resize());

        let mut fixed = window("fixed", 1, Some("org.example.Dialog"));
        fixed.is_fixed_sized = true;
        assert!(fixed.allows_interactive_resize());
    }

    #[test]
    fn window_placement_derives_the_surface_origin() {
        let placement = crate::meta_window_state::meta_window::WindowPlacement {
            origin: Point::from((48, 48)),
            client_size: (2512, 1356).into(),
            geometry_offset: Point::from((24, 21)),
        };

        assert_eq!(placement.surface_origin(), Point::from((24.0, 27.0)));
        assert_eq!(
            placement.client_rect(),
            Rectangle::new((48, 48).into(), (2512, 1356).into())
        );
    }

    #[test]
    fn surface_origin_accounts_for_a_wayland_csd_geometry_offset() {
        let mut window = window("wayland", 42, Some("firefox"));
        window.position = Some(Point::from((48, 48)).into());
        window.geometry = Some(Rectangle::new((24, 21).into(), (2512, 1356).into()).into());

        assert_eq!(window.surface_origin(), Some(Point::from((24.0, 27.0))));
    }

    #[test]
    fn surface_origin_of_an_x11_window_is_its_root_position() {
        let mut window = window("x11", 42, Some("zoom"));
        window.position = Some(Point::from((710, 326)).into());
        window.geometry = Some(Rectangle::new((0, 0).into(), (1188, 800).into()).into());

        assert_eq!(window.surface_origin(), Some(Point::from((710.0, 326.0))));
    }

    #[test]
    fn surface_origin_at_uses_the_window_geometry() {
        let mut window = window("wayland", 42, Some("firefox"));
        window.geometry = Some(Rectangle::new((24, 21).into(), (2512, 1356).into()).into());

        assert_eq!(
            window.surface_origin_at(Point::from((100.0, 200.0))),
            Point::from((76.0, 179.0))
        );
    }

    #[test]
    fn consumer_pid_wins_over_app_id() {
        let state = state_with(
            vec![
                window("by-pid", 42, Some("org.example.Other")),
                window("by-app", 7, Some("org.example.App")),
            ],
            &["by-app"],
        );
        assert_eq!(
            state.recording_meta_window_for("org.example.App", None, Some(42)),
            Some("by-pid".to_string())
        );
    }

    #[test]
    fn app_id_fallback_picks_most_recently_focused() {
        let state = state_with(
            vec![
                window("older", 7, Some("org.example.App")),
                window("recent", 8, Some("org.example.App")),
            ],
            &["older", "recent"],
        );
        assert_eq!(
            state.recording_meta_window_for("org.example.App", None, None),
            Some("recent".to_string())
        );
    }

    #[test]
    fn app_id_fallback_falls_back_to_any_match_without_focus_history() {
        let state = state_with(vec![window("only", 7, Some("org.example.App"))], &[]);
        assert_eq!(
            state.recording_meta_window_for("org.example.App", None, None),
            Some("only".to_string())
        );
    }

    #[test]
    fn app_id_matching_ignores_case_and_desktop_suffix() {
        let state = state_with(vec![window("w", 7, Some("org.example.App.desktop"))], &[]);
        assert_eq!(
            state.recording_meta_window_for("org.example.app", None, None),
            Some("w".to_string())
        );
    }

    #[test]
    fn unknown_identity_resolves_to_nothing() {
        let state = state_with(vec![window("w", 7, Some("org.example.App"))], &["w"]);
        assert_eq!(state.recording_meta_window_for("", None, None), None);
        assert_eq!(
            state.recording_meta_window_for("org.example.Other", None, None),
            None
        );
    }

    #[test]
    fn unknown_pid_still_falls_back_to_the_app_id() {
        let state = state_with(vec![window("w", 7, Some("org.example.App"))], &["w"]);
        assert_eq!(
            state.recording_meta_window_for("org.example.App", None, Some(999)),
            Some("w".to_string())
        );
    }

    #[test]
    fn consumer_node_hint_matches_the_binary_name() {
        // The portal proxies the stream, so the pid is the portal's; the
        // consumer node is named after the browser binary (`node.name=brave`)
        // while the window app id is `brave-browser`.
        let mut browser = window("browser", 42, Some("brave-browser"));
        browser.binary_name = Some("brave".to_string());
        let state = state_with(vec![browser], &[]);
        assert_eq!(
            state.recording_meta_window_for("", Some("brave"), Some(4097)),
            Some("browser".to_string())
        );
    }

    #[test]
    fn removed_window_leaves_the_focus_order() {
        let mut state = state_with(vec![window("w", 7, Some("org.example.App"))], &["w"]);
        state.forget_meta_window("w");
        assert!(state.focus_order.is_empty());
    }

    #[test]
    fn game_mode_windows_are_scoped_to_their_output() {
        let mut on_first = window("first", 1, None);
        on_first.game_mode_activated = true;
        on_first.current_output = Some("DP-1".to_string());
        let mut on_second = window("second", 2, None);
        on_second.game_mode_activated = true;
        on_second.current_output = Some("HDMI-A-1".to_string());
        let state = state_with(vec![on_first, on_second], &[]);

        assert_eq!(
            state.game_mode_window_ids_for_output("DP-1"),
            vec!["first".to_string()]
        );
        assert_eq!(
            state.game_mode_window_ids_for_output("HDMI-A-1"),
            vec!["second".to_string()]
        );
        assert!(state.game_mode_window_ids_for_output("eDP-1").is_empty());
    }

    #[test]
    fn non_game_windows_are_never_in_game_mode() {
        let mut idle = window("idle", 1, None);
        idle.current_output = Some("DP-1".to_string());
        let state = state_with(vec![idle], &[]);
        assert!(state.game_mode_window_ids_for_output("DP-1").is_empty());
    }

    #[test]
    fn snap_security_labels_resolve_to_the_desktop_app_id() {
        assert_eq!(
            snap_app_id_from_security_label("snap.firefox.firefox (enforce)").as_deref(),
            Some("firefox_firefox")
        );
        assert_eq!(
            snap_app_id_from_security_label("snap.some-snap.some-app (complain)").as_deref(),
            Some("some-snap_some-app")
        );
    }

    #[test]
    fn non_snap_security_labels_are_never_treated_as_snaps() {
        // Fedora/SELinux: every process has a label in /proc/<pid>/attr/current,
        // so a permissive "the file exists" check used to return the context as
        // the app id and break window matching.
        assert_eq!(
            snap_app_id_from_security_label(
                "unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023\0"
            ),
            None
        );
        assert_eq!(
            snap_app_id_from_security_label("docker-default (enforce)"),
            None
        );
        assert_eq!(snap_app_id_from_security_label("unconfined"), None);
        assert_eq!(snap_app_id_from_security_label(""), None);
    }
}
