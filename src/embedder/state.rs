use std::collections::{HashMap, HashSet};
use std::os::fd::OwnedFd;
use std::sync::atomic::AtomicBool;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use smithay::backend::allocator::dmabuf::Dmabuf;
use smithay::backend::input::KeyState;
use smithay::backend::renderer::gles::ffi::Gles2;
use smithay::delegate_dispatch2;
use smithay::desktop::{Space, Window};
use smithay::input::dnd::{DnDGrab, DndGrabHandler, GrabType, Source};
use smithay::input::keyboard::{KeyboardHandle, XkbConfig};
use smithay::input::pointer::{CursorImageStatus, Focus, PointerHandle};
use smithay::input::{Seat, SeatHandler, SeatState};
use smithay::output::{Output, Scale};
use smithay::reexports::calloop::generic::Generic;
use smithay::reexports::calloop::{Interest, LoopHandle, Mode, PostAction};
use smithay::reexports::input;
use smithay::reexports::wayland_protocols::xdg::decoration::zv1::server::zxdg_toplevel_decoration_v1;
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel::WmCapabilities;
use smithay::reexports::wayland_server::protocol::wl_buffer;
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::reexports::wayland_server::{Display, DisplayHandle, Resource};
use smithay::reexports::x11rb::protocol::xproto::Window as X11Window;
use smithay::utils::{
    Buffer as BufferCoords, Clock, Logical, Monotonic, Point, Rectangle, Serial, Size, Transform,
};
use smithay::wayland::buffer::BufferHandler;
use smithay::wayland::compositor::{self, get_parent, RectangleKind};
use smithay::wayland::compositor::{
    with_states, CompositorState, SubsurfaceCachedState, SurfaceAttributes,
};
use smithay::wayland::dmabuf::DmabufState;
use smithay::wayland::fractional_scale::{
    with_fractional_scale, FractionalScaleHandler, FractionalScaleManagerState,
};
use smithay::wayland::idle_inhibit::{IdleInhibitHandler, IdleInhibitManagerState};
use smithay::wayland::idle_notify::{IdleNotifierHandler, IdleNotifierState};
use smithay::wayland::output::OutputHandler;
use smithay::wayland::relative_pointer::RelativePointerManagerState;
use smithay::wayland::seat::WaylandFocus;
use smithay::wayland::selection::data_device::{
    set_data_device_focus, DataDeviceHandler, DataDeviceState, WaylandDndGrabHandler,
};
use smithay::wayland::selection::primary_selection::{
    set_primary_focus, PrimarySelectionHandler, PrimarySelectionState,
};
use smithay::wayland::selection::wlr_data_control::{DataControlHandler, DataControlState};
use smithay::wayland::selection::{SelectionHandler, SelectionSource, SelectionTarget};
use smithay::wayland::shell::xdg;
use smithay::wayland::shell::xdg::decoration::XdgDecorationState;
use smithay::wayland::shell::xdg::dialog::XdgDialogState;
use smithay::wayland::shell::xdg::{
    PopupSurface, SurfaceCachedState, ToplevelSurface, XdgPopupSurfaceData, XdgShellState,
    XdgToplevelSurfaceData,
};
use smithay::wayland::shm::{ShmHandler, ShmState};
use smithay::wayland::socket::ListeningSocketSource;
use smithay::wayland::xdg_activation::{XdgActivationState, XdgActivationToken};
use smithay::wayland::xwayland_shell::{self, XWAYLAND_SHELL_ROLE};
use smithay::xwayland::{X11Surface, X11Wm};
use tracing::{info, warn};
use xkbcommon::xkb::Keycode;

use crate::cursor::CursorState;
use crate::flutter_engine::view::OutputViewIdWrapper;
use crate::flutter_engine::wayland_messages::{
    PopupMessage, SubsurfaceMessage, SurfaceMessage, SurfaceRole, ToplevelMessage,
    XdgSurfaceMessage, XdgSurfaceRole,
};
use crate::flutter_engine::FlutterEngine;
use crate::focus::{KeyboardFocusTarget, PointerFocusTarget};
use crate::keyboard::key_repeater::KeyRepeater;
use crate::keyboard::{handle_keyboard_event, swap_left_alt_and_meta, VeshellKeyEvent};
use crate::meta_window_state::meta_window::MetaWindowPatch;
use crate::meta_window_state::MetaWindowState;
use crate::settings::{MonitorConfiguration, SettingsManager, VeshellSettings};
use crate::texture_swap_chain::TextureSwapChain;
use crate::wayland::wayland::{get_direct_subsurfaces, get_surface_id};
use crate::wayland::xwayland::xwayland::XWaylandState;
use crate::{flutter_engine, Backend, ClientState};

pub struct State<BackendData: Backend + 'static> {
    pub backend_data: Box<BackendData>,
    pub batons: Vec<flutter_engine::Baton>,
    pub clock: Clock<Monotonic>,
    pub compositor_state: CompositorState,
    pub data_control_state: DataControlState,
    pub data_device_state: DataDeviceState,
    pub display_handle: DisplayHandle,
    pub dmabuf_state: Option<DmabufState>,
    pub flutter_engine: Option<Box<FlutterEngine<BackendData>>>,
    pub flutter_sent_keys: HashMap<Keycode, VeshellKeyEvent>,
    pub super_key_forwarding: crate::keyboard::SuperKeyForwarding,
    /// Keycodes forwarded to the gaming-mode client and still held. Used to
    /// replay the matching releases when gaming mode ends, so the client can't
    /// keep believing the Ctrl of `Ctrl+Esc` (or any other held key) is down.
    pub game_mode_forwarded_keys: HashSet<Keycode>,
    pub gl: Option<Gles2>,
    pub imported_dmabufs: Vec<Dmabuf>,
    pub is_next_flutter_frame_scheduled: bool,
    pub keyboard: KeyboardHandle<State<BackendData>>,
    pub key_repeater: KeyRepeater<BackendData>,
    pub loop_handle: LoopHandle<'static, State<BackendData>>,
    pub next_surface_id: u64,
    pub next_texture_id: i64,
    pub next_x11_surface_id: u64,
    pub pointer: PointerHandle<State<BackendData>>,
    pub pointer_frame_pending: bool,
    pub primary_selection_state: PrimarySelectionState,
    pub repeat_delay: u64,
    pub repeat_rate: u64,
    pub running: Arc<AtomicBool>,
    pub seat: Seat<State<BackendData>>,
    pub seat_state: SeatState<State<BackendData>>,
    pub shm_state: ShmState,
    pub space: Space<Window>,
    pub surface_id_per_texture_id: HashMap<i64, u64>,
    pub surface_id_under_cursor: Option<u64>,
    pub pointer_focus: Option<(PointerFocusTarget, Point<f64, Logical>)>,
    pub surfaces: HashMap<u64, WlSurface>,
    pub subsurfaces: HashMap<u64, WlSurface>,
    pub texture_ids_per_surface_id: HashMap<u64, Vec<(i64, Size<i32, BufferCoords>)>>,
    pub texture_swapchains: HashMap<i64, TextureSwapChain>,
    pub wayland_socket_name: Option<String>,
    pub x11_surfaces: HashMap<u64, X11Surface>,
    pub x11_surface_per_wl_surface: HashMap<WlSurface, X11Surface>,
    pub x11_surface_per_x11_window: HashMap<X11Window, X11Surface>,
    pub xdg_activation_state: XdgActivationState,
    /// Activation tokens minted for invoked notification actions, mapping the
    /// token to the meta window the action belongs to. When a client turns one
    /// of these into an `xdg_activation_v1` request, the window is focused —
    /// the user invoked the action — instead of being read as a demand for
    /// attention. Single-use, pruned by age.
    pub notification_activation_tokens: HashMap<String, (String, Instant)>,
    pub xdg_dialog_state: XdgDialogState,
    pub xdg_popups: HashMap<u64, PopupSurface>,
    pub xdg_shell_state: XdgShellState,
    pub xdg_toplevels: HashMap<u64, ToplevelSurface>,
    pub meta_window_state: MetaWindowState,
    pub xwayland_shell_state: xwayland_shell::XWaylandShellState,
    pub xwayland_state: Option<XWaylandState>,
    pub cursor_state: CursorState,
    pub cursor_image_status: Mutex<CursorImageStatus>,
    pub settings_manager: SettingsManager<BackendData>,
    pub xdg_decoration_state: XdgDecorationState,
    pub fractional_scale_manager_state: FractionalScaleManagerState,
    pub input_devices: HashSet<input::Device>,
    pub output_layout_revision: u64,
    /// Screensaver: idle stage machine driving the dim overlay and blanking.
    pub idle: crate::idle::IdleState<BackendData>,
    /// ext-idle-notify-v1: lets clients learn when the user became active.
    pub idle_notifier_state: IdleNotifierState<State<BackendData>>,
    /// idle-inhibit-unstable-v1: clients can suppress idleness from here.
    pub idle_inhibit_manager_state: IdleInhibitManagerState,
    /// Display backlight: the physical brightness the screensaver fades and the
    /// brightness keys drive. Unavailable when no controllable panel exists, in
    /// which case the screensaver keeps the black overlay.
    pub brightness: crate::brightness::Brightness,
    /// Capture-owned state: the native selection session, the local recording
    /// session, and the channels that carry their worker results back onto the
    /// compositor loop.
    pub capture_state: crate::capture::CaptureState,
    /// Portal-owned state: the backend runtime, the screenshot/pick-color
    /// encode bridge, and the PipeWire producer with its live screen-cast
    /// streams.
    pub portal_state: crate::portal::PortalState,
    /// Notification-owned state: the freedesktop notifications transport
    /// server and the loop-side reply table for accepted calls.
    pub notification_state: crate::notification::NotificationState,
    /// View (monitor) that received the start of the current pointer gesture
    /// (button-held drag, trackpad pan/zoom scroll, or pinch). Every later
    /// event of that gesture is pinned to this view so Flutter sees one
    /// consistent `view_id` and coordinate space even if the pointer crosses
    /// monitors mid-gesture. `None` when no gesture is in progress.
    pub pointer_gesture_view_id: Option<i64>,
    /// Desired mirror source (connector name) per monitor, keyed by connector.
    ///
    /// Written from each monitor's `monitor/<connector>.json` when its
    /// configuration is applied; resolved against the live outputs by
    /// [`State::mirror_source`]. Absent means a regular display. See
    /// `docs/specifications/monitor.md`.
    pub mirror_of: HashMap<String, String>,
}

impl<BackendData: Backend + 'static> State<BackendData> {
    pub fn get_new_surface_id(&mut self) -> u64 {
        let surface_id = self.next_surface_id;
        self.next_surface_id += 1;
        surface_id
    }

    pub fn get_new_x11_surface_id(&mut self) -> u64 {
        let x11_surface_id = self.next_x11_surface_id;
        self.next_x11_surface_id += 1;
        x11_surface_id
    }

    pub fn get_new_texture_id(&mut self) -> i64 {
        let texture_id = self.next_texture_id;
        self.next_texture_id += 1;
        texture_id
    }

    /// Releases the shell's external texture `texture_id`: forgets its
    /// swapchain and unregisters it from Flutter so the engine stops asking for
    /// frames and can free its GPU resources.
    pub fn release_texture_id(&mut self, texture_id: i64) {
        self.texture_swapchains.remove(&texture_id);
        self.surface_id_per_texture_id.remove(&texture_id);
        if let Err(err) = self
            .flutter_engine()
            .unregister_external_texture(texture_id)
        {
            warn!(texture_id, error = %err, "Failed to unregister external texture");
        }
    }

    /// Releases every external texture owned by `surface_id`, used when the
    /// surface is destroyed. The bookkeeping for the surface is forgotten so a
    /// long-lived session cannot accumulate one entry per closed surface.
    pub fn release_surface_textures(&mut self, surface_id: u64) {
        if let Some(texture_ids) = self.texture_ids_per_surface_id.remove(&surface_id) {
            for (texture_id, _) in texture_ids {
                self.release_texture_id(texture_id);
            }
        }
    }

    pub fn release_all_keys(&mut self) {
        let keyboard = self.keyboard.clone();
        for mut key_code in keyboard.pressed_keys() {
            key_code = swap_left_alt_and_meta(self, key_code);
            // Focus loss is not a user key-up gesture, but Flutter still needs its key state cleared.
            handle_keyboard_event::<BackendData>(self, key_code, KeyState::Released, 0, true);
        }
    }

    pub fn frame_timestamp_millis(&self) -> u32 {
        self.clock.now().as_millis() as u32
    }

    /// Tells the shell the display brightness changed so it can show the
    /// brightness OSD. Called after every user-driven [`crate::brightness::Brightness::adjust`]
    /// (the hardware function keys handled in the compositor, and the shell's
    /// own `adjust_brightness` request). A no-op when no controllable backlight
    /// exists: there is nothing to report, and the shell should not show an OSD
    /// for a panel it cannot dim.
    pub fn notify_brightness_changed(&mut self) {
        if !self.brightness.is_available() {
            return;
        }
        let fraction = self.brightness.user_fraction();
        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "brightness_changed",
            Some(Box::new(serde_json::json!({ "fraction": fraction }))),
            None,
        );
    }
}

impl<BackendData: Backend + 'static> DndGrabHandler for State<BackendData> {}

impl<BackendData: Backend + 'static> State<BackendData> {
    pub fn flutter_engine(&self) -> &FlutterEngine<BackendData> {
        self.flutter_engine.as_ref().unwrap()
    }
    pub fn flutter_engine_mut(&mut self) -> &mut FlutterEngine<BackendData> {
        self.flutter_engine.as_mut().unwrap()
    }
}

// Smithay 0.7 centralizes protocol delegation through Dispatch2.
delegate_dispatch2!(@<BackendData: Backend + 'static> State<BackendData>);

impl<BackendData: Backend + 'static> State<BackendData> {
    pub fn new(
        display: Display<State<BackendData>>,
        loop_handle: LoopHandle<'static, State<BackendData>>,
        backend_data: BackendData,
        dmabuf_state: Option<DmabufState>,
        settings_manager: SettingsManager<BackendData>,
    ) -> State<BackendData> {
        let display_handle = display.handle();
        let clock = Clock::new();
        let compositor_state = CompositorState::new::<Self>(&display_handle);
        let xdg_shell_state = XdgShellState::new_with_capabilities::<Self>(
            &display_handle,
            [WmCapabilities::Fullscreen],
        );
        let shm_state = ShmState::new::<Self>(&display_handle, vec![]);

        // init input
        let mut seat_state = SeatState::new();
        let seat_name = backend_data.seat_name();
        let mut seat = seat_state.new_wl_seat(&display_handle, seat_name.clone());

        let settings = settings_manager.get_settings();

        let repeat_delay: u64 = 200;
        let repeat_rate: u64 = 50;
        let keyboard = seat
            .add_keyboard(
                XkbConfig {
                    layout: &settings.keyboard.layout,
                    ..XkbConfig::default()
                },
                repeat_delay as i32,
                repeat_rate as i32,
            )
            .unwrap();

        let pointer = seat.add_pointer();
        // Expose global only if backend supports relative motion events
        if BackendData::HAS_RELATIVE_MOTION {
            RelativePointerManagerState::new::<Self>(&display_handle);
        }

        let data_device_state = DataDeviceState::new::<Self>(&display_handle);
        let primary_selection_state = PrimarySelectionState::new::<Self>(&display_handle);
        let data_control_state = DataControlState::new::<Self, _>(
            &display_handle,
            Some(&primary_selection_state),
            |_| true,
        );

        // init wayland clients
        let source = ListeningSocketSource::new_auto().unwrap();
        let socket_name = source.socket_name().to_string_lossy().into_owned();
        loop_handle
            .insert_source(source, |client_stream, _, data| {
                if let Err(err) = data
                    .display_handle
                    .insert_client(client_stream, Arc::new(ClientState::default()))
                {
                    warn!("Error adding wayland client: {}", err);
                };
            })
            .expect("Failed to init wayland socket source");

        info!(name = socket_name, "Listening on wayland socket");
        // Set WAYLAND_DISPLAY for children.

        std::env::set_var("WAYLAND_DISPLAY", socket_name.clone());
        // Set the current desktop for xdg-desktop-portal.
        std::env::set_var("XDG_CURRENT_DESKTOP", "veshell");
        // Ensure the session type is set to Wayland for xdg-autostart and Qt apps.
        std::env::set_var("XDG_SESSION_TYPE", "wayland");
        std::env::set_var("GDK_BACKEND", "wayland"); // Force GTK apps to run on Wayland.
        std::env::set_var("QT_QPA_PLATFORM", "wayland"); // Force QT apps to run on Wayland.

        loop_handle
            .insert_source(
                Generic::new(display, Interest::READ, Mode::Level),
                |_, display, data| {
                    profiling::scope!("dispatch_clients");
                    // Safety: we don't drop the display
                    unsafe {
                        display.get_mut().dispatch_clients(data).unwrap();
                    }
                    Ok(PostAction::Continue)
                },
            )
            .expect("Failed to init wayland server source");

        let key_repeater = KeyRepeater::new(
            loop_handle.clone(),
            |event, data: &mut State<BackendData>| {
                data.flutter_engine
                    .as_mut()
                    .unwrap()
                    .send_key_event(event, true)
                    .expect("Failed to send key event");
            },
        );

        let xwayland_shell_state = xwayland_shell::XWaylandShellState::new::<Self>(&display_handle);
        let xdg_decoration_state = XdgDecorationState::new::<Self>(&display_handle);
        let xdg_dialog_state = XdgDialogState::new::<Self>(&display_handle);
        let xdg_activation_state = XdgActivationState::new::<Self>(&display_handle);
        let fractional_scale_manager_state =
            FractionalScaleManagerState::new::<Self>(&display_handle);
        let capture_state = crate::capture::CaptureState::new::<BackendData>(&loop_handle);
        let portal_state = crate::portal::PortalState::new::<BackendData>(&loop_handle);
        let notification_state =
            crate::notification::NotificationState::new::<BackendData>(&loop_handle);
        let idle_notifier_state =
            IdleNotifierState::<Self>::new(&display_handle, loop_handle.clone());
        let idle_inhibit_manager_state = IdleInhibitManagerState::new::<Self>(&display_handle);
        let brightness =
            crate::brightness::Brightness::new(<BackendData as Backend>::CONTROLS_BACKLIGHT);
        let idle = crate::idle::IdleState::new(
            loop_handle.clone(),
            &settings.idle,
            brightness.is_available(),
        );

        let mut state = Self {
            running: Arc::new(AtomicBool::new(true)),
            display_handle,
            loop_handle,
            clock,
            batons: vec![],
            backend_data: Box::new(backend_data),
            surface_id_under_cursor: None,
            is_next_flutter_frame_scheduled: false,
            compositor_state,
            xdg_shell_state,
            shm_state,
            flutter_engine: None,
            flutter_sent_keys: HashMap::new(),
            super_key_forwarding: Default::default(),
            game_mode_forwarded_keys: HashSet::new(),
            dmabuf_state,
            seat,
            seat_state,
            data_device_state,
            primary_selection_state,
            data_control_state,
            pointer,
            pointer_frame_pending: false,
            keyboard,
            repeat_delay,
            repeat_rate,
            key_repeater,
            wayland_socket_name: Some(socket_name),
            next_surface_id: 1,
            next_x11_surface_id: 1,
            next_texture_id: 1,
            imported_dmabufs: Vec::new(),
            gl: None,
            surfaces: HashMap::new(),
            subsurfaces: HashMap::new(),
            xdg_toplevels: HashMap::new(),
            xdg_popups: HashMap::new(),
            xdg_dialog_state,
            xdg_activation_state,
            notification_activation_tokens: HashMap::new(),
            meta_window_state: MetaWindowState::new(),
            x11_surfaces: HashMap::new(),
            x11_surface_per_x11_window: HashMap::new(),
            x11_surface_per_wl_surface: HashMap::new(),
            texture_ids_per_surface_id: HashMap::new(),
            surface_id_per_texture_id: HashMap::new(),
            texture_swapchains: HashMap::new(),
            xwayland_shell_state,
            xwayland_state: None,
            space: Space::default(),
            pointer_focus: None,
            cursor_state: CursorState::default(),
            cursor_image_status: Mutex::new(CursorImageStatus::default_named()),
            settings_manager,
            xdg_decoration_state,
            fractional_scale_manager_state,
            input_devices: HashSet::new(),
            output_layout_revision: 0,
            capture_state,
            portal_state,
            notification_state,
            pointer_gesture_view_id: None,
            mirror_of: HashMap::new(),
            idle,
            idle_notifier_state,
            idle_inhibit_manager_state,
            brightness,
        };
        // Start watching for idleness right away.
        state.idle.arm_activity_timers();
        state
    }

    /// Mints an activation token for a notification action and records the
    /// meta window it may activate. The returned string is what the D-Bus
    /// `ActivationToken` signal carries; the client hands it back through
    /// `xdg_activation_v1`.
    pub fn mint_notification_activation_token(&mut self, meta_window_id: &str) -> String {
        self.prune_notification_activation_tokens();
        let token = self
            .xdg_activation_state
            .create_external_token(None)
            .0
            .as_str()
            .to_owned();
        self.notification_activation_tokens
            .insert(token.clone(), (meta_window_id.to_owned(), Instant::now()));
        token
    }

    /// Consumes the notification activation token `token`, returning the meta
    /// window it was minted for. `None` when the token is not one of ours (a
    /// client-created activation), which keeps the ordinary activation path.
    pub fn take_notification_activation_token(&mut self, token: &str) -> Option<String> {
        self.notification_activation_tokens
            .remove(token)
            .map(|(meta_window_id, _)| meta_window_id)
    }

    /// Drops notification activation tokens that were minted but never used,
    /// so a client that ignores the signal cannot leak tokens forever.
    fn prune_notification_activation_tokens(&mut self) {
        // A client normally activates within milliseconds of the signal.
        const TOKEN_TTL: Duration = Duration::from_secs(30);
        let stale: Vec<String> = self
            .notification_activation_tokens
            .iter()
            .filter(|(_, (_, minted))| minted.elapsed() > TOKEN_TTL)
            .map(|(token, _)| token.clone())
            .collect();
        for token in stale {
            self.xdg_activation_state
                .remove_token(&XdgActivationToken::from(token.clone()));
            self.notification_activation_tokens.remove(&token);
        }
    }

    pub fn change_keyboard_repeat_info(&mut self, repeat_delay: u64, repeat_rate: u64) {
        self.repeat_delay = repeat_delay;
        self.repeat_rate = repeat_rate;
        self.keyboard
            .change_repeat_info(repeat_delay as i32, repeat_rate as i32);
    }

    pub fn apply_veshell_settings(&mut self, settings: &VeshellSettings) {
        crate::idle::apply_idle_settings(self, &settings.idle);
        let keyboard = self.keyboard.clone();
        keyboard
            .set_xkb_config(
                self,
                XkbConfig {
                    layout: &settings.keyboard.layout.clone(),
                    ..XkbConfig::default()
                },
            )
            .unwrap();
    }

    pub fn construct_surface_message(&self, surface: &WlSurface) -> SurfaceMessage {
        let surface_id = get_surface_id(surface);
        let role = self.construct_surface_role_message(surface);

        let (buffer_delta, buffer_scale, input_region) = with_states(surface, |surface_data| {
            let mut binding = surface_data.cached_state.get::<SurfaceAttributes>();
            let surface_state = binding.current();
            let buffer_delta = surface_state.buffer_delta;
            let buffer_scale = surface_state.buffer_scale;
            let input_region = surface_state.input_region.clone();
            (buffer_delta, buffer_scale, input_region)
        });

        let (texture_id, buffer_size) = self
            .texture_ids_per_surface_id
            .get(&surface_id)
            .and_then(|ids| ids.last().cloned())
            .and_then(|(id, size)| Some((id, Some(size))))
            .unwrap_or((0, None));

        // TODO: Serialize all the rectangles instead of merging them into one.
        let input_region = if let Some(input_region) = input_region {
            let mut acc: Option<Rectangle<i32, Logical>> = None;
            for (kind, rect) in input_region.rects {
                if let RectangleKind::Add = kind {
                    if let Some(acc_) = acc {
                        acc = Some(acc_.merge(rect));
                    } else {
                        acc = Some(rect);
                    }
                }
            }
            acc.unwrap_or_default()
        } else {
            // TODO: Account for DPI scaling.
            buffer_size
                .map(|size| Rectangle::new((0, 0).into(), (size.w, size.h).into()))
                .unwrap_or_default()
        };

        let (subsurfaces_below, subsurfaces_above) = get_direct_subsurfaces(surface);

        let message = SurfaceMessage {
            surface_id,
            role,
            texture_id,
            buffer_delta: buffer_delta.map(|delta| delta.into()),
            buffer_size: buffer_size.map(|b| b.into()),
            scale: buffer_scale,
            input_region: input_region.into(),
            subsurfaces_below,
            subsurfaces_above,
        };
        tracing::debug!(
            target: "veshell::geometry",
            surface_id,
            texture_id = message.texture_id,
            buffer_size = ?message.buffer_size,
            buffer_scale = message.scale,
            buffer_delta = ?message.buffer_delta,
            input_region = ?message.input_region,
            "Constructed surface geometry snapshot"
        );
        message
    }

    fn construct_surface_role_message(&self, surface: &WlSurface) -> Option<SurfaceRole> {
        let role = with_states(surface, |surface_data| surface_data.role);
        match role {
            Some(compositor::SUBSURFACE_ROLE) => {
                let subsurface_message = Self::construct_subsurface_role_message(surface);
                Some(SurfaceRole::Subsurface(subsurface_message))
            }
            _ => None,
        }
    }

    pub fn construct_subsurface_role_message(surface: &WlSurface) -> SubsurfaceMessage {
        // `wl_subsurface.set_position` modifies double-buffered state of the
        // *parent* surface, so it takes effect on the parent's commit even when
        // the child is desynchronized and never committed itself. Smithay only
        // moves the child's pending location to `current` on the child's own
        // commit, so read the pending one: the parent-commit recursion below
        // re-emits this message precisely to surface such state.
        let location = with_states(surface, |surface_data| {
            surface_data
                .cached_state
                .get::<SubsurfaceCachedState>()
                .pending()
                .location
        });

        SubsurfaceMessage {
            position: location.into(),
            parent: get_surface_id(&get_parent(surface).unwrap()),
        }
    }

    pub fn get_output_by_name(&self, name: &str) -> Option<&Output> {
        self.space.outputs().find(|output| output.name() == name)
    }

    pub fn map_output(&mut self, output: &Output, location: Point<i32, Logical>) {
        self.space.map_output(output, location);
        self.output_layout_changed();
    }

    pub fn unmap_output(&mut self, output: &Output) {
        self.space.unmap_output(output);
        self.output_layout_changed();
    }

    pub fn output_layout_changed(&mut self) {
        self.space.refresh();
        self.output_layout_revision = self.output_layout_revision.wrapping_add(1);
        // The frozen image no longer describes the layout: abort the
        // capture session instead of producing a broken screenshot.
        crate::capture::cancel_capture_session(self);
    }

    /// Applies a desired [`MonitorConfiguration`] to a live `Output`,
    /// best-effort.
    ///
    /// Requested changes the hardware rejects simply do not happen; the next
    /// `output_layout_changed` publishes the actual state back to Flutter.
    /// Rust's `Output` remains the authoritative *actual* state. See
    /// `docs/specifications/monitor.md` (section "State ownership").
    pub fn apply_monitor_configuration_to_output(
        &mut self,
        output: &Output,
        configuration: MonitorConfiguration,
    ) -> bool {
        let new_mode = if output.current_mode().unwrap() != configuration.mode.into() {
            Some(configuration.mode.into())
        } else {
            None
        };

        let new_scale =
            if output.current_scale().fractional_scale() != configuration.fractionnal_scale {
                Some(Scale::Fractional(configuration.fractionnal_scale))
            } else {
                None
            };

        let new_location = if output.current_location() != configuration.location.into() {
            Some(configuration.location.into())
        } else {
            None
        };

        // The transform is only meaningful on backends that apply an output
        // transform; a nested backend keeps its own correction transform.
        let desired_transform = if BackendData::SUPPORTS_OUTPUT_TRANSFORM {
            Transform::from(configuration.transform)
        } else {
            output.current_transform()
        };
        let new_transform = if output.current_transform() != desired_transform {
            Some(desired_transform)
        } else {
            None
        };

        // The desired mirror target is resolved against the live outputs at
        // render and input time; here we only record it and notice the change
        // so the layout is republished.
        let previous_mirror = self.mirror_of.get(&output.name()).cloned();
        let mirror_changed = previous_mirror.as_deref() != configuration.mirror_of.as_deref();
        if mirror_changed {
            match &configuration.mirror_of {
                Some(target) => {
                    self.mirror_of.insert(output.name(), target.clone());
                }
                None => {
                    self.mirror_of.remove(&output.name());
                }
            }
        }

        // if any new apply changes and return true
        if new_mode.is_some()
            || new_scale.is_some()
            || new_location.is_some()
            || new_transform.is_some()
            || mirror_changed
        {
            output.change_current_state(new_mode, new_transform, new_scale, new_location);
            if new_location.is_some() {
                self.space.map_output(output, output.current_location());
            }
            self.output_layout_changed();
            if new_mode.is_some() {
                output.set_preferred(new_mode.unwrap());
            }
            // if scale changed update the scale for all MetaWindow displayed on it
            if new_scale.is_some() {
                for meta_window in self
                    .meta_window_state
                    .get_meta_windows_for_output(output.clone())
                {
                    self.patch_meta_window(
                        MetaWindowPatch::UpdateScaleRatio {
                            id: meta_window.clone().id,
                            value: new_scale.unwrap().fractional_scale(),
                        },
                        true,
                    );
                }
            }
            // if mode or transform changed update the view size (a quarter
            // turn transposes the output's logical size)
            if let Some(view_id) = output
                .user_data()
                .get::<OutputViewIdWrapper>()
                .map(|wrapper| wrapper.view_id)
            {
                self.flutter_engine
                    .as_mut()
                    .unwrap()
                    .resize_view(view_id, output)
                    .expect("Failed to resize view");
            }

            true
        } else {
            false
        }
    }

    /// Resolves the live monitor that `output` should mirror right now.
    ///
    /// The mirror is one level deep: the target must be connected and must
    /// itself be a regular display (not configured to mirror). Any other
    /// situation — absent target, self target, or a target that is itself a
    /// follower — falls back to `None`, i.e. a regular display. See
    /// `docs/specifications/monitor.md`.
    pub fn mirror_source(&self, output: &Output) -> Option<Output> {
        let target_name = self.mirror_of.get(&output.name())?;
        if target_name == &output.name() || self.mirror_of.contains_key(target_name) {
            return None;
        }
        self.get_output_by_name(target_name).cloned()
    }

    pub fn on_outputs_changed(&mut self) {
        let outputs = self.space.outputs().cloned().collect::<Vec<_>>();
        let revision = self.output_layout_revision;
        for output in &outputs {
            tracing::info!(
                target: "veshell::geometry",
                output = %output.name(),
                output_id = ?output.user_data().get::<OutputViewIdWrapper>().map(|id| id.view_id),
                location = ?output.current_location(),
                size = ?output.current_mode().map(|mode| mode.size),
                scale = output.current_scale().fractional_scale(),
                revision,
                "Publishing output geometry to Flutter"
            );
        }
        self.flutter_engine_mut()
            .monitor_layout_changed(outputs.clone(), revision);

        let highest_scale = outputs
            .iter()
            .map(|output| output.current_scale().fractional_scale())
            .fold(f64::NAN, |acc, x| match acc.partial_cmp(&x) {
                Some(std::cmp::Ordering::Less) | None => x,
                _ => acc,
            });

        let highest_scale = if highest_scale.is_nan() {
            1.0
        } else {
            highest_scale
        };

        self.update_xwayland_scale(highest_scale);
    }
}

impl<BackendData: Backend> BufferHandler for State<BackendData> {
    fn buffer_destroyed(&mut self, _buffer: &wl_buffer::WlBuffer) {}
}

impl<BackendData: Backend> ShmHandler for State<BackendData> {
    fn shm_state(&self) -> &ShmState {
        &self.shm_state
    }
}

impl<BackendData: Backend> SeatHandler for State<BackendData> {
    type KeyboardFocus = KeyboardFocusTarget;
    type PointerFocus = PointerFocusTarget;
    type TouchFocus = PointerFocusTarget;

    fn seat_state(&mut self) -> &mut SeatState<State<BackendData>> {
        &mut self.seat_state
    }

    fn focus_changed(&mut self, seat: &Seat<Self>, target: Option<&KeyboardFocusTarget>) {
        let dh = &self.display_handle;
        let wl_surface = target.and_then(WaylandFocus::wl_surface);
        let client = wl_surface.and_then(|s| dh.get_client(s.id()).ok());
        set_data_device_focus(dh, seat, client.clone());
        set_primary_focus(dh, seat, client);
    }

    fn cursor_image(&mut self, _seat: &Seat<Self>, image: CursorImageStatus) {
        *self.cursor_image_status.lock().unwrap() = image;
    }
}

impl<BackendData: Backend> SelectionHandler for State<BackendData> {
    type SelectionUserData = crate::capture::selection::SelectionUserData;

    fn new_selection(
        &mut self,
        ty: SelectionTarget,
        source: Option<SelectionSource>,
        _seat: Seat<Self>,
    ) {
        if let Some(xwm) = self
            .xwayland_state
            .as_mut()
            .and_then(|state| state.xwm.as_mut())
        {
            if let Err(err) = xwm.new_selection(ty, source.map(|source| source.mime_types())) {
                warn!(?err, ?ty, "Failed to set Xwayland selection");
            }
        }
    }

    fn send_selection(
        &mut self,
        ty: SelectionTarget,
        mime_type: String,
        fd: OwnedFd,
        _seat: Seat<Self>,
        user_data: &Self::SelectionUserData,
    ) {
        if let Some(data) = user_data {
            if mime_type == crate::capture::selection::PNG_MIME
                || mime_type == crate::capture::selection::NATIVE_SCREENSHOT_MIME
            {
                crate::capture::selection::send_native_selection(fd, data.clone());
                return;
            }
        }
        if let Some(xwm) = self
            .xwayland_state
            .as_mut()
            .and_then(|state| state.xwm.as_mut())
        {
            if let Err(err) = xwm.send_selection(ty, mime_type, fd) {
                warn!(?err, "Failed to send primary (X11 -> Wayland)");
            }
        }
    }
}

impl<BackendData: Backend + 'static> WaylandDndGrabHandler for State<BackendData> {
    fn dnd_requested<S: Source>(
        &mut self,
        source: S,
        _icon: Option<WlSurface>,
        seat: Seat<Self>,
        serial: Serial,
        type_: GrabType,
    ) {
        // A client (e.g. a browser starting a tab or file drag) asked to begin
        // a drag in response to the pointer press that installed the implicit
        // click grab. Install a real `DnDGrab` so the drag is actually driven;
        // the trait's default implementation cancels the source and drops the
        // drag on the floor.
        match type_ {
            GrabType::Pointer => {
                let Some(pointer) = seat.get_pointer() else {
                    source.cancel();
                    return;
                };
                let Some(start_data) = pointer.grab_start_data() else {
                    source.cancel();
                    return;
                };
                let grab =
                    DnDGrab::new_pointer(&self.display_handle, start_data, source, seat.clone());
                pointer.set_grab(self, grab, serial, Focus::Keep);
            }
            GrabType::Touch => {
                let Some(touch) = seat.get_touch() else {
                    source.cancel();
                    return;
                };
                let Some(start_data) = touch.grab_start_data() else {
                    source.cancel();
                    return;
                };
                let grab = DnDGrab::new_touch(&self.display_handle, start_data, source, seat);
                touch.set_grab(self, grab, serial);
            }
        }
    }
}

impl<BackendData: Backend> DataDeviceHandler for State<BackendData> {
    fn data_device_state(&mut self) -> &mut DataDeviceState {
        &mut self.data_device_state
    }
}

impl<BackendData: Backend> OutputHandler for State<BackendData> {}

impl<BackendData: Backend> PrimarySelectionHandler for State<BackendData> {
    fn primary_selection_state(&mut self) -> &mut PrimarySelectionState {
        &mut self.primary_selection_state
    }
}
impl<BackendData: Backend> DataControlHandler for State<BackendData> {
    fn data_control_state(&mut self) -> &mut DataControlState {
        &mut self.data_control_state
    }
}

impl<BackendData: Backend> IdleNotifierHandler for State<BackendData> {
    fn idle_notifier_state(&mut self) -> &mut IdleNotifierState<Self> {
        &mut self.idle_notifier_state
    }
}

impl<BackendData: Backend> IdleInhibitHandler for State<BackendData> {
    fn inhibit(&mut self, surface: WlSurface) {
        self.idle.inhibiting_surfaces.push(surface);
        crate::idle::refresh_idle_inhibit(self);
    }

    fn uninhibit(&mut self, surface: WlSurface) {
        self.idle.inhibiting_surfaces.retain(|s| *s != surface);
        crate::idle::refresh_idle_inhibit(self);
    }
}
