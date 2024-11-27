use std::collections::HashMap;
use std::os::fd::OwnedFd;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};

use log::error;
use smithay::backend::allocator::dmabuf::Dmabuf;
use smithay::backend::input::{KeyState, Keycode};
use smithay::backend::renderer::gles::ffi::Gles2;
use smithay::backend::renderer::gles::GlesRenderer;
use smithay::backend::renderer::ImportDma;
use smithay::backend::session::Session;
use smithay::desktop::{Space, Window};
use smithay::input::keyboard::{KeyboardHandle, Keysym, ModifiersState, XkbConfig};
use smithay::input::pointer::{CursorImageStatus, PointerHandle};
use smithay::input::{Seat, SeatHandler, SeatState};
use smithay::reexports::calloop::channel::Event::Msg;
use smithay::reexports::calloop::generic::Generic;
use smithay::reexports::calloop::{channel, Interest, LoopHandle, Mode, PostAction};
use smithay::reexports::wayland_protocols::xdg::decoration::zv1::server::zxdg_toplevel_decoration_v1;
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;
use smithay::reexports::wayland_server::protocol::wl_buffer;
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::reexports::wayland_server::{Display, DisplayHandle, Resource};
use smithay::reexports::x11rb::protocol::xproto::Window as X11Window;
use smithay::utils::{
    Buffer as BufferCoords, Clock, Logical, Monotonic, Point, Rectangle, Size, SERIAL_COUNTER,
};
use smithay::wayland::buffer::BufferHandler;
use smithay::wayland::compositor::{self, get_parent, RectangleKind};
use smithay::wayland::compositor::{
    with_states, CompositorState, SubsurfaceCachedState, SurfaceAttributes,
};
use smithay::wayland::dmabuf::{DmabufGlobal, DmabufHandler, DmabufState, ImportNotifier};
use smithay::wayland::output::OutputHandler;
use smithay::wayland::relative_pointer::RelativePointerManagerState;
use smithay::wayland::seat::WaylandFocus;
use smithay::wayland::selection::data_device::{
    set_data_device_focus, ClientDndGrabHandler, DataDeviceHandler, DataDeviceState,
    ServerDndGrabHandler,
};
use smithay::wayland::selection::primary_selection::{
    set_primary_focus, PrimarySelectionHandler, PrimarySelectionState,
};
use smithay::wayland::selection::wlr_data_control::{DataControlHandler, DataControlState};
use smithay::wayland::selection::{SelectionHandler, SelectionSource, SelectionTarget};
use smithay::wayland::shell::xdg;
use smithay::wayland::shell::xdg::{
    PopupSurface, SurfaceCachedState, ToplevelSurface, XdgPopupSurfaceData, XdgShellState,
    XdgToplevelSurfaceData,
};
use smithay::wayland::shm::{ShmHandler, ShmState};
use smithay::wayland::socket::ListeningSocketSource;
use smithay::wayland::xwayland_shell::{self, XWAYLAND_SHELL_ROLE};
use smithay::xwayland::{X11Surface, X11Wm};
use smithay::{
    delegate_compositor, delegate_data_control, delegate_data_device, delegate_dmabuf,
    delegate_output, delegate_primary_selection, delegate_relative_pointer, delegate_seat,
    delegate_shm, delegate_xdg_shell, delegate_xwayland_shell,
};
use tracing::{info, warn};

use crate::cursor::CursorState;
use crate::flutter_engine::wayland_messages::{
    PopupMessage, SubsurfaceMessage, SurfaceMessage, SurfaceRole, ToplevelMessage,
    XdgSurfaceMessage, XdgSurfaceRole,
};
use crate::flutter_engine::FlutterEngine;
use crate::focus::{KeyboardFocusTarget, PointerFocusTarget};
use crate::keyboard::key_repeater::KeyRepeater;
use crate::keyboard::KeyEvent;
use crate::texture_swap_chain::TextureSwapChain;
use crate::wayland::wayland::{get_direct_subsurfaces, get_surface_id};
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
    pub gl: Option<Gles2>,
    pub gles_renderer: Option<GlesRenderer>,
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
    pub tx_fbo: Option<channel::Sender<Option<Dmabuf>>>,
    pub tx_flutter_handled_key_event: channel::Sender<(KeyEvent, bool)>,
    pub wayland_socket_name: Option<String>,
    pub x11_surface_per_wl_surface: HashMap<WlSurface, X11Surface>,
    pub x11_surface_per_x11_window: HashMap<X11Window, X11Surface>,
    pub x11_wm: Option<X11Wm>,
    pub xdg_popups: HashMap<u64, PopupSurface>,
    pub xdg_shell_state: XdgShellState,
    pub xdg_toplevels: HashMap<u64, ToplevelSurface>,
    pub xwayland_display: Option<u32>,
    pub xwayland_shell_state: xwayland_shell::XWaylandShellState,
    pub cursor_state: CursorState,
    pub cursor_image_status: Mutex<CursorImageStatus>,
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

    pub fn handle_key_event(&mut self, mut key_code: Keycode, state: KeyState, time: u32) {
        // Update the state of the keyboard.
        // Every key event must be passed through `glfw_key_codes.input_intercept`
        // so that Smithay knows what keys are pressed.
        let keyboard = self.keyboard.clone();
        let mut linux_code = key_code.raw() - 8;

        // Swap Meta ant leftAlt keycode
        if linux_code == input_linux::sys::KEY_LEFTMETA as u32 {
            linux_code = input_linux::sys::KEY_LEFTALT as u32
        } else if linux_code == input_linux::sys::KEY_LEFTALT as u32 {
            linux_code = input_linux::sys::KEY_LEFTMETA as u32
        }

        key_code = Keycode::new(linux_code + 8);
        info!("keycode {:?}", key_code,);

        // 1. Update the Smithay keyboard state but intercept the event so it's not forwarded to the focused client just yet
        let ((mods, keysym), mods_changed) =
            keyboard.input_intercept::<_, _>(self, key_code, state, |_, mods, keysym_handle| {
                // 2. Retrieve the keysym and modifiers with the xkb layout applied
                (*mods, keysym_handle.modified_sym())
            });

        info!(
            ?state,
            mods = ?mods,
            keysym = ::xkbcommon::xkb::keysym_get_name(keysym),
            "keysym",
        );

        // 3. Check if the keystroke result in compositor hotkeys shortcuts

        // Switching to another VT
        if (Keysym::XF86_Switch_VT_1.raw()..=Keysym::XF86_Switch_VT_12.raw())
            .contains(&keysym.raw())
        {
            if let Err(_err) = self
                .backend_data
                .get_session()
                .change_vt((keysym.raw() - Keysym::XF86_Switch_VT_1.raw() + 1) as i32)
            {
                error!("Failed switching virtual terminal.");
            }
        }

        // Exiting the compositor
        if keysym == Keysym::Escape && mods.alt {
            self.running.store(false, Ordering::SeqCst);
            return;
        }

        // 4. Forward the key event to Flutter.
        self.flutter_engine.as_mut().unwrap().send_key_event(
            self.tx_flutter_handled_key_event.clone(),
            KeyEvent {
                key_code: linux_code,
                specified_logical_key: None,
                codepoint: keysym.key_char(),
                state,
                time,
                mods,
                mods_changed,
            },
        );

        // Initiate key repeat.
        // The callback that gets called repeatedly is defined in the constructor of `State`.
        // Modifier keys do nothing on their own, so it doesn't make sense to repeat them.
        // TODO: It would be nice to be able to define the callback here next to this block of code
        // because asynchronous flows like this one are difficult to follow.
        if !mods_changed {
            match state {
                KeyState::Pressed => {
                    self.key_repeater.down(
                        linux_code,
                        keysym.key_char(),
                        Duration::from_millis(self.repeat_delay),
                        Duration::from_millis(self.repeat_rate),
                    );
                }
                KeyState::Released => {
                    self.key_repeater.up(linux_code);
                }
            }
        }
    }

    pub fn release_all_keys(&mut self) {
        let keyboard = self.keyboard.clone();
        for key_code in keyboard.pressed_keys() {
            self.handle_key_event(key_code, KeyState::Released, 0);
        }
    }
}

impl<BackendData: Backend + 'static> State<BackendData> {
    pub fn flutter_engine(&self) -> &FlutterEngine<BackendData> {
        self.flutter_engine.as_ref().unwrap()
    }
    pub fn flutter_engine_mut(&mut self) -> &mut FlutterEngine<BackendData> {
        self.flutter_engine.as_mut().unwrap()
    }
}

// Macros used to delegate protocol handling to types in the app state.
delegate_compositor!(@<BackendData: Backend + 'static> State<BackendData>);
delegate_xdg_shell!(@<BackendData: Backend + 'static> State<BackendData>);
delegate_shm!(@<BackendData: Backend + 'static> State<BackendData>);
delegate_dmabuf!(@<BackendData: Backend + 'static> State<BackendData>);
delegate_output!(@<BackendData: Backend + 'static> State<BackendData>);
delegate_seat!(@<BackendData: Backend + 'static> State<BackendData>);
delegate_data_device!(@<BackendData: Backend + 'static> State<BackendData>);
delegate_xwayland_shell!(@<BackendData: Backend + 'static> State<BackendData>);
delegate_relative_pointer!(@<BackendData: Backend + 'static> State<BackendData>);

impl<BackendData: Backend + 'static> State<BackendData> {
    pub fn new(
        display: Display<State<BackendData>>,
        loop_handle: LoopHandle<'static, State<BackendData>>,
        backend_data: BackendData,
        dmabuf_state: Option<DmabufState>,
    ) -> State<BackendData> {
        let display_handle = display.handle();
        let clock = Clock::new();
        let compositor_state = CompositorState::new::<Self>(&display_handle);
        let xdg_shell_state = XdgShellState::new::<Self>(&display_handle);
        let shm_state = ShmState::new::<Self>(&display_handle, vec![]);

        // init input
        let mut seat_state = SeatState::new();
        let seat_name = backend_data.seat_name();
        let mut seat = seat_state.new_wl_seat(&display_handle, seat_name.clone());

        let repeat_delay: u64 = 200;
        let repeat_rate: u64 = 50;
        let keyboard = seat
            .add_keyboard(
                XkbConfig {
                    layout: "us(altgr-intl)",
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

        let (tx_flutter_handled_key_event, rx_flutter_handled_key_event) =
            channel::channel::<(KeyEvent, bool)>();

        loop_handle
            .insert_source(
                rx_flutter_handled_key_event,
                move |event, _, data: &mut State<BackendData>| {
                    if let Msg((key_event, handled)) = event {
                        if handled {
                            // Flutter consumed this event. Probably a keyboard shortcut.
                            return;
                        }

                        let text_input = &mut data.flutter_engine.as_mut().unwrap().text_input;
                        if text_input.is_active() {
                            if key_event.state == KeyState::Pressed
                                && !key_event.mods.ctrl
                                && !key_event.mods.alt
                            {
                                text_input.press_key(key_event.key_code, key_event.codepoint);
                            }
                            // It doesn't matter if the text field captured the key event or not.
                            // As long as it stays active, don't forward events to the Wayland client.
                            return;
                        }

                        // The compositor was not interested in this event,
                        // so we forward it to the Wayland client in focus if there is one.
                        let keyboard = data.keyboard.clone();
                        keyboard.input_forward(
                            data,
                            Keycode::new(key_event.key_code + 8),
                            key_event.state,
                            SERIAL_COUNTER.next_serial(),
                            key_event.time,
                            key_event.mods_changed,
                        );
                    }
                },
            )
            .unwrap();

        let key_repeater = KeyRepeater::new(
            loop_handle.clone(),
            |key_code, code_point, data: &mut State<BackendData>| {
                let keyboard = data.keyboard.clone();

                let mods = keyboard.modifier_state();
                data.flutter_engine.as_mut().unwrap().send_key_event(
                    data.tx_flutter_handled_key_event.clone(),
                    KeyEvent {
                        key_code,
                        specified_logical_key: None,
                        codepoint: code_point,
                        state: KeyState::Pressed,
                        time: SystemTime::now()
                            .duration_since(SystemTime::UNIX_EPOCH)
                            .unwrap()
                            .as_millis() as u32,
                        mods: ModifiersState {
                            alt: true,
                            ctrl: false,
                            shift: false,
                            caps_lock: false,
                            logo: false,
                            num_lock: false,
                            iso_level3_shift: false,
                            serialized: mods.serialized,
                            iso_level5_shift: false,
                        },
                        mods_changed: false,
                    },
                );
            },
        );

        let xwayland_shell_state = xwayland_shell::XWaylandShellState::new::<Self>(&display_handle);

        Self {
            running: Arc::new(AtomicBool::new(true)),
            display_handle,
            loop_handle,
            clock,
            tx_fbo: None,
            batons: vec![],
            backend_data: Box::new(backend_data),
            surface_id_under_cursor: None,
            is_next_flutter_frame_scheduled: false,
            compositor_state,
            xdg_shell_state,
            shm_state,
            flutter_engine: None,
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
            tx_flutter_handled_key_event,
            key_repeater,
            x11_wm: None,
            wayland_socket_name: Some(socket_name),
            xwayland_display: None,
            next_surface_id: 1,
            next_x11_surface_id: 1,
            next_texture_id: 1,
            imported_dmabufs: Vec::new(),
            gles_renderer: None,
            gl: None,
            surfaces: HashMap::new(),
            subsurfaces: HashMap::new(),
            xdg_toplevels: HashMap::new(),
            xdg_popups: HashMap::new(),
            x11_surface_per_x11_window: HashMap::new(),
            x11_surface_per_wl_surface: HashMap::new(),
            texture_ids_per_surface_id: HashMap::new(),
            surface_id_per_texture_id: HashMap::new(),
            texture_swapchains: HashMap::new(),
            xwayland_shell_state,
            space: Space::default(),
            pointer_focus: None,
            cursor_state: CursorState::default(),
            cursor_image_status: Mutex::new(CursorImageStatus::default_named()),
        }
    }

    pub fn change_keyboard_repeat_info(&mut self, repeat_delay: u64, repeat_rate: u64) {
        self.repeat_delay = repeat_delay;
        self.repeat_rate = repeat_rate;
        self.keyboard
            .change_repeat_info(repeat_delay as i32, repeat_rate as i32);
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
                .map(|size| Rectangle::from_loc_and_size((0, 0), (size.w, size.h)))
                .unwrap_or_default()
        };

        let (subsurfaces_below, subsurfaces_above) = get_direct_subsurfaces(surface);

        SurfaceMessage {
            surface_id,
            role,
            texture_id,
            buffer_delta: buffer_delta.map(|delta| delta.into()),
            buffer_size: buffer_size.map(|b| b.into()),
            scale: buffer_scale,
            input_region: input_region.into(),
            subsurfaces_below,
            subsurfaces_above,
        }
    }

    fn construct_surface_role_message(&self, surface: &WlSurface) -> Option<SurfaceRole> {
        let role = with_states(surface, |surface_data| surface_data.role);
        match role {
            Some(role @ (xdg::XDG_TOPLEVEL_ROLE | xdg::XDG_POPUP_ROLE)) => {
                let xdg_surface_message = self.construct_xdg_surface_role_message(surface, role);
                Some(SurfaceRole::XdgSurface(xdg_surface_message))
            }
            Some(compositor::SUBSURFACE_ROLE) => {
                let subsurface_message = Self::construct_subsurface_role_message(surface);
                Some(SurfaceRole::Subsurface(subsurface_message))
            }
            Some(XWAYLAND_SHELL_ROLE) => Some(SurfaceRole::X11Surface),
            _ => None,
        }
    }

    fn construct_xdg_surface_role_message(
        &self,
        surface: &WlSurface,
        role: &str,
    ) -> XdgSurfaceMessage {
        let geometry = with_states(surface, |surface_data| {
            surface_data
                .cached_state
                .get::<SurfaceCachedState>()
                .current()
                .geometry
                .map(|geometry| geometry.into())
        });

        let role = (|| match role {
            xdg::XDG_TOPLEVEL_ROLE => {
                let toplevel_message = self.construct_toplevel_role_message(surface)?;
                Some(XdgSurfaceRole::XdgToplevel(toplevel_message))
            }
            xdg::XDG_POPUP_ROLE => {
                let popup_message = self.construct_popup_role_message(surface)?;
                Some(XdgSurfaceRole::XdgPopup(popup_message))
            }
            _ => unreachable!("This function must only be called with xdg roles"),
        })();

        XdgSurfaceMessage { geometry, role }
    }

    pub fn construct_subsurface_role_message(surface: &WlSurface) -> SubsurfaceMessage {
        let location = with_states(surface, |surface_data| {
            surface_data
                .cached_state
                .get::<SubsurfaceCachedState>()
                .current()
                .location
        });

        SubsurfaceMessage {
            position: location.into(),
            parent: get_surface_id(&get_parent(surface).unwrap()),
        }
    }

    fn construct_toplevel_role_message(&self, surface: &WlSurface) -> Option<ToplevelMessage> {
        let surface_id = get_surface_id(surface);
        let toplevel = self.xdg_toplevels.get(&surface_id)?;

        let (initial_configure_sent, parent, app_id, title) =
            with_states(surface, |surface_data| {
                let surface_state = surface_data
                    .data_map
                    .get::<XdgToplevelSurfaceData>()
                    .unwrap()
                    .lock()
                    .unwrap();
                (
                    surface_state.initial_configure_sent,
                    surface_state.parent.clone(),
                    surface_state.app_id.clone(),
                    surface_state.title.clone(),
                )
            });

        toplevel.with_pending_state(|state| {
            state.states.set(xdg_toplevel::State::Maximized);
            state.decoration_mode = Some(zxdg_toplevel_decoration_v1::Mode::ServerSide);
        });

        if !initial_configure_sent {
            toplevel.send_configure();
            return None;
        }

        let parent_id = if let Some(ref parent) = parent {
            Some(get_surface_id(&parent))
        } else {
            None
        };

        Some(ToplevelMessage {
            parent_surface_id: parent_id,
            app_id,
            title,
        })
    }

    pub fn construct_popup_role_message(&self, surface: &WlSurface) -> Option<PopupMessage> {
        let surface_id = get_surface_id(surface);
        let popup = self.xdg_popups.get(&surface_id)?;
        let (initial_configure_sent, parent, position) = with_states(surface, |surface_data| {
            let surface_state = surface_data
                .data_map
                .get::<XdgPopupSurfaceData>()
                .unwrap()
                .lock()
                .unwrap();

            (
                surface_state.initial_configure_sent,
                surface_state.parent.clone(),
                surface_state.current.geometry.loc.into(),
            )
        });

        if !initial_configure_sent {
            // NOTE: This should never fail as the initial configure is always
            // allowed.
            popup.send_configure().expect("initial configure failed");
            return None;
        }

        let parent = get_surface_id(&parent?);

        Some(PopupMessage { parent, position })
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

impl<BackendData: Backend> DmabufHandler for State<BackendData> {
    fn dmabuf_state(&mut self) -> &mut DmabufState {
        self.dmabuf_state.as_mut().unwrap()
    }

    fn dmabuf_imported(
        &mut self,
        _global: &DmabufGlobal,
        dmabuf: Dmabuf,
        notifier: ImportNotifier,
    ) {
        // TODO
        if self
            .gles_renderer
            .as_mut()
            .unwrap()
            .import_dmabuf(&dmabuf, None)
            .is_ok()
        {
            let _ = notifier.successful::<State<BackendData>>();
            self.imported_dmabufs.push(dmabuf);
        } else {
            notifier.failed();
        }
    }
}

// impl DmabufHandler for State<X11Data> {
//     fn dmabuf_state(&mut self) -> &mut DmabufState {
//         &mut self.dmabuf_state.as_mut().unwrap()
//     }
//
//     fn dmabuf_imported(&mut self, _global: &DmabufGlobal, dmabuf: Dmabuf) -> Result<(), ImportError> {
//         self.backend_data
//             .gles_renderer
//             .import_dmabuf(&dmabuf, None)
//             .map(|_| ())
//             .map_err(|_| ImportError::Failed)
//     }
// }

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
        info!("cursor_image {:?}", image);
        *self.cursor_image_status.lock().unwrap() = image;
    }
}

impl<BackendData: Backend> SelectionHandler for State<BackendData> {
    type SelectionUserData = ();

    fn new_selection(
        &mut self,
        ty: SelectionTarget,
        source: Option<SelectionSource>,
        _seat: Seat<Self>,
    ) {
        if let Some(xwm) = self.x11_wm.as_mut() {
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
        _user_data: &(),
    ) {
        if let Some(xwm) = self.x11_wm.as_mut() {
            if let Err(err) = xwm.send_selection(ty, mime_type, fd, self.loop_handle.clone()) {
                warn!(?err, "Failed to send primary (X11 -> Wayland)");
            }
        }
    }
}

impl<BackendData: Backend> ClientDndGrabHandler for State<BackendData> {}

impl<BackendData: Backend> ServerDndGrabHandler for State<BackendData> {}

impl<BackendData: Backend> DataDeviceHandler for State<BackendData> {
    fn data_device_state(&self) -> &DataDeviceState {
        &self.data_device_state
    }
}

impl<BackendData: Backend> OutputHandler for State<BackendData> {}

impl<BackendData: Backend> PrimarySelectionHandler for State<BackendData> {
    fn primary_selection_state(&self) -> &PrimarySelectionState {
        &self.primary_selection_state
    }
}
delegate_primary_selection!(@<BackendData: Backend + 'static> State<BackendData>);

impl<BackendData: Backend> DataControlHandler for State<BackendData> {
    fn data_control_state(&self) -> &DataControlState {
        &self.data_control_state
    }
}
delegate_data_control!(@<BackendData: Backend + 'static> State<BackendData>);
