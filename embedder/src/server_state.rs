use serde_json::json;
use std::cell::RefCell;
use std::collections::HashMap;
use std::env::{remove_var, set_var};
use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::{Duration, SystemTime};

use smithay::backend::allocator::dmabuf::Dmabuf;
use smithay::backend::input::KeyState;
use smithay::backend::renderer::gles::ffi::Gles2;
use smithay::backend::renderer::gles::GlesRenderer;
use smithay::backend::renderer::{ImportAll, Texture};
use smithay::input::keyboard::KeyboardHandle;
use smithay::input::pointer::{CursorImageStatus, PointerHandle};
use smithay::input::{Seat, SeatHandler, SeatState};
use smithay::reexports::calloop::channel::Event::Msg;
use smithay::reexports::calloop::generic::Generic;
use smithay::reexports::calloop::{channel, Interest, LoopHandle, Mode, PostAction};
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;
use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel::ResizeEdge;
use smithay::reexports::wayland_server::protocol::wl_buffer;
use smithay::reexports::wayland_server::protocol::wl_seat::WlSeat;
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::reexports::wayland_server::{Client, Display, DisplayHandle, Resource};
use smithay::utils::{
    Buffer as BufferCoords, Clock, Logical, Monotonic, Rectangle, Serial, Size, SERIAL_COUNTER,
};
use smithay::wayland::buffer::BufferHandler;
use smithay::wayland::compositor::{self, get_parent, RectangleKind};
use smithay::wayland::compositor::{
    with_states, with_surface_tree_upward, BufferAssignment, CompositorClientState,
    CompositorHandler, CompositorState, SubsurfaceCachedState, SurfaceAttributes, TraversalAction,
};
use smithay::wayland::dmabuf::{DmabufGlobal, DmabufHandler, DmabufState, ImportNotifier};
use smithay::wayland::selection::data_device::{
    set_data_device_focus, ClientDndGrabHandler, DataDeviceHandler, DataDeviceState,
    ServerDndGrabHandler,
};
use smithay::wayland::selection::SelectionHandler;
use smithay::wayland::shell::xdg;
use smithay::wayland::shell::xdg::{
    PopupState, PopupSurface, PositionerState, SurfaceCachedState, ToplevelSurface,
    XdgPopupSurfaceData, XdgShellHandler, XdgShellState, XdgToplevelSurfaceData,
};
use smithay::wayland::shm::{ShmHandler, ShmState};
use smithay::wayland::socket::ListeningSocketSource;
use smithay::{
    delegate_compositor, delegate_data_device, delegate_dmabuf, delegate_output, delegate_seat,
    delegate_shm, delegate_xdg_shell,
};
use tracing::{info, warn};

use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;
use crate::flutter_engine::wayland_messages::{
    MyPoint, MyRectangle, PopupMessage, SubsurfaceMessage, SurfaceMessage, SurfaceRole,
    ToplevelMessage, XdgSurfaceMessage, XdgSurfaceRole,
};
use crate::flutter_engine::FlutterEngine;
use crate::keyboard::key_repeater::KeyRepeater;
use crate::keyboard::KeyEvent;
use crate::texture_swap_chain::TextureSwapChain;
use crate::{Backend, CalloopData, ClientState};

pub struct ServerState<BackendData: Backend + 'static> {
    pub running: Arc<AtomicBool>,
    pub display_handle: DisplayHandle,
    pub loop_handle: LoopHandle<'static, CalloopData<BackendData>>,
    pub clock: Clock<Monotonic>,
    pub seat: Seat<ServerState<BackendData>>,
    pub seat_state: SeatState<ServerState<BackendData>>,
    pub data_device_state: DataDeviceState,
    pub pointer: PointerHandle<ServerState<BackendData>>,
    pub keyboard: KeyboardHandle<ServerState<BackendData>>,
    pub repeat_delay: u64,
    pub repeat_rate: u64,
    pub tx_flutter_handled_key_event: channel::Sender<(KeyEvent, bool)>,
    pub key_repeater: KeyRepeater<BackendData>,

    pub backend_data: Box<BackendData>,
    pub flutter_engine: Option<Box<FlutterEngine<BackendData>>>,
    pub next_surface_id: u64,
    pub next_texture_id: i64,

    pub mouse_position: (f64, f64),
    pub surface_id_under_cursor: Option<u64>,
    pub is_next_flutter_frame_scheduled: bool,

    pub compositor_state: CompositorState,
    pub xdg_shell_state: XdgShellState,
    pub shm_state: ShmState,
    pub dmabuf_state: Option<DmabufState>,

    pub imported_dmabufs: Vec<Dmabuf>,
    pub gles_renderer: Option<GlesRenderer>,
    pub gl: Option<Gles2>,
    pub surfaces: HashMap<u64, WlSurface>,
    pub xdg_toplevels: HashMap<u64, ToplevelSurface>,
    pub xdg_popups: HashMap<u64, PopupSurface>,
    pub texture_ids_per_surface_id: HashMap<u64, Vec<(i64, Size<i32, BufferCoords>)>>,
    pub surface_id_per_texture_id: HashMap<i64, u64>,
    pub texture_swapchains: HashMap<i64, TextureSwapChain>,
}

impl<BackendData: Backend + 'static> ServerState<BackendData> {
    pub fn get_new_surface_id(&mut self) -> u64 {
        let surface_id = self.next_surface_id;
        self.next_surface_id += 1;
        surface_id
    }

    pub fn get_new_texture_id(&mut self) -> i64 {
        let texture_id = self.next_texture_id;
        self.next_texture_id += 1;
        texture_id
    }

    pub fn handle_key_event(&mut self, key_code: u32, state: KeyState, time: u32) {
        // Update the state of the keyboard.
        // Every key event must be passed through `glfw_key_codes.input_intercept`
        // so that Smithay knows what keys are pressed.
        let keyboard = self.keyboard.clone();
        let ((mods, utf32_codepoint), mods_changed) =
            keyboard.input_intercept::<_, _>(self, key_code, state, |_, mods, keysym_handle| {
                // After updating the keyboard state,
                // we get the state of the modifiers and the character that was typed.
                let utf32_codepoint = keysym_handle.modified_sym().key_char();
                (*mods, utf32_codepoint)
            });

        // Forward the key event to Flutter.
        self.flutter_engine.as_mut().unwrap().send_key_event(
            self.tx_flutter_handled_key_event.clone(),
            KeyEvent {
                key_code,
                codepoint: utf32_codepoint,
                state,
                time,
                mods,
                mods_changed,
            },
        );

        // Initiate key repeat.
        // The callback that gets called repeatedly is defined in the constructor of `ServerState`.
        // Modifier keys do nothing on their own, so it doesn't make sense to repeat them.
        // TODO: It would be nice to be able to define the callback here next to this block of code
        // because asynchronous flows like this one are difficult to follow.
        if !mods_changed {
            match state {
                KeyState::Pressed => {
                    self.key_repeater.down(
                        key_code,
                        utf32_codepoint,
                        Duration::from_millis(self.repeat_delay),
                        Duration::from_millis(self.repeat_rate),
                    );
                }
                KeyState::Released => {
                    self.key_repeater.up(key_code);
                }
            }
        }
    }

    pub fn release_all_keys(&mut self) {
        let keyboard = self.keyboard.clone();
        for key_code in keyboard.pressed_keys() {
            self.handle_key_event(key_code.raw(), KeyState::Released, 0);
        }
    }
}

impl<BackendData: Backend + 'static> ServerState<BackendData> {
    pub fn flutter_engine(&self) -> &FlutterEngine<BackendData> {
        self.flutter_engine.as_ref().unwrap()
    }
    pub fn flutter_engine_mut(&mut self) -> &mut FlutterEngine<BackendData> {
        self.flutter_engine.as_mut().unwrap()
    }
}

// Macros used to delegate protocol handling to types in the app state.
delegate_compositor!(@<BackendData: Backend + 'static> ServerState<BackendData>);
delegate_xdg_shell!(@<BackendData: Backend + 'static> ServerState<BackendData>);
delegate_shm!(@<BackendData: Backend + 'static> ServerState<BackendData>);
delegate_dmabuf!(@<BackendData: Backend + 'static> ServerState<BackendData>);
delegate_output!(@<BackendData: Backend + 'static> ServerState<BackendData>);
delegate_seat!(@<BackendData: Backend + 'static> ServerState<BackendData>);
delegate_data_device!(@<BackendData: Backend + 'static> ServerState<BackendData>);

impl<BackendData: Backend + 'static> ServerState<BackendData> {
    pub fn new(
        display: Display<ServerState<BackendData>>,
        loop_handle: LoopHandle<'static, CalloopData<BackendData>>,
        backend_data: BackendData,
        dmabuf_state: Option<DmabufState>,
    ) -> ServerState<BackendData> {
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
            .add_keyboard(Default::default(), repeat_delay as i32, repeat_rate as i32)
            .unwrap();

        let pointer = seat.add_pointer();

        let data_device_state = DataDeviceState::new::<Self>(&display_handle);

        // init wayland clients
        let source = ListeningSocketSource::new_auto().unwrap();
        let socket_name = source.socket_name().to_string_lossy().into_owned();
        loop_handle
            .insert_source(source, |client_stream, _, data| {
                if let Err(err) = data
                    .state
                    .display_handle
                    .insert_client(client_stream, Arc::new(ClientState::default()))
                {
                    warn!("Error adding wayland client: {}", err);
                };
            })
            .expect("Failed to init wayland socket source");

        info!(name = socket_name, "Listening on wayland socket");

        remove_var("DISPLAY");
        set_var("WAYLAND_DISPLAY", &socket_name);
        set_var("XDG_SESSION_TYPE", "wayland");
        set_var("GDK_BACKEND", "wayland"); // Force GTK apps to run on Wayland.
        set_var("QT_QPA_PLATFORM", "wayland"); // Force QT apps to run on Wayland.

        loop_handle
            .insert_source(
                Generic::new(display, Interest::READ, Mode::Level),
                |_, display, data| {
                    profiling::scope!("dispatch_clients");
                    // Safety: we don't drop the display
                    unsafe {
                        display.get_mut().dispatch_clients(&mut data.state).unwrap();
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
                move |event, _, data: &mut CalloopData<BackendData>| {
                    if let Msg((key_event, handled)) = event {
                        if handled {
                            // Flutter consumed this event. Probably a keyboard shortcut.
                            return;
                        }

                        let text_input =
                            &mut data.state.flutter_engine.as_mut().unwrap().text_input;
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
                        let keyboard = data.state.keyboard.clone();
                        keyboard.input_forward(
                            &mut data.state,
                            key_event.key_code,
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
            |key_code, code_point, data: &mut CalloopData<BackendData>| {
                let keyboard = data.state.keyboard.clone();

                let mods = keyboard.modifier_state();
                data.state.flutter_engine.as_mut().unwrap().send_key_event(
                    data.state.tx_flutter_handled_key_event.clone(),
                    KeyEvent {
                        key_code,
                        codepoint: code_point,
                        state: KeyState::Pressed,
                        time: SystemTime::now()
                            .duration_since(SystemTime::UNIX_EPOCH)
                            .unwrap()
                            .as_millis() as u32,
                        mods,
                        mods_changed: false,
                    },
                );
            },
        );

        Self {
            running: Arc::new(AtomicBool::new(true)),
            display_handle,
            loop_handle,
            clock,
            backend_data: Box::new(backend_data),
            mouse_position: (0.0, 0.0),
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
            pointer,
            keyboard,
            repeat_delay,
            repeat_rate,
            tx_flutter_handled_key_event,
            key_repeater,
            next_surface_id: 1,
            next_texture_id: 1,
            imported_dmabufs: Vec::new(),
            gles_renderer: None,
            gl: None,
            surfaces: HashMap::new(),
            xdg_toplevels: HashMap::new(),
            xdg_popups: HashMap::new(),
            texture_ids_per_surface_id: HashMap::new(),
            surface_id_per_texture_id: HashMap::new(),
            texture_swapchains: HashMap::new(),
        }
    }

    pub fn change_keyboard_repeat_info(&mut self, repeat_delay: u64, repeat_rate: u64) {
        self.repeat_delay = repeat_delay;
        self.repeat_rate = repeat_rate;
        self.keyboard
            .change_repeat_info(repeat_delay as i32, repeat_rate as i32);
    }

    fn construct_surface_message(&self, surface: &WlSurface) -> SurfaceMessage {
        let surface_id = get_surface_id(surface);
        let role = self.construct_surface_role_message(surface);

        let (buffer_delta, buffer_scale, input_region) = with_states(surface, |surface_data| {
            let surface_state = surface_data.cached_state.current::<SurfaceAttributes>();
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
                .current::<SurfaceCachedState>()
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

    fn construct_subsurface_role_message(surface: &WlSurface) -> SubsurfaceMessage {
        let location = with_states(surface, |surface_data| {
            surface_data
                .cached_state
                .current::<SubsurfaceCachedState>()
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

        let (initial_configure_sent, parent) = with_states(surface, |surface_data| {
            let surface_state = surface_data
                .data_map
                .get::<XdgToplevelSurfaceData>()
                .unwrap()
                .lock()
                .unwrap();
            (
                surface_state.initial_configure_sent,
                surface_state.parent.clone(),
            )
        });

        toplevel.with_pending_state(|state| {
            state.states.set(xdg_toplevel::State::Maximized);
        });

        if !initial_configure_sent {
            toplevel.send_configure();
        }

        let parent_id = if let Some(ref parent) = parent {
            Some(get_surface_id(&parent))
        } else {
            None
        };

        let (app_id, title) = with_states(surface, |surface_data| {
            let surface_state = surface_data
                .data_map
                .get::<XdgToplevelSurfaceData>()
                .unwrap()
                .lock()
                .unwrap();
            (
                surface_state.app_id.clone().unwrap_or_default(),
                surface_state.title.clone().unwrap_or_default(),
            )
        });

        Some(ToplevelMessage {
            app_id,
            title,
            parent_surface_id: parent_id,
        })
    }

    fn construct_popup_role_message(&self, surface: &WlSurface) -> Option<PopupMessage> {
        let surface_id = get_surface_id(surface);
        let popup = self.xdg_popups.get(&surface_id)?;
        let (initial_configure_sent, parent) = with_states(surface, |surface_data| {
            let surface_state = surface_data
                .data_map
                .get::<XdgPopupSurfaceData>()
                .unwrap()
                .lock()
                .unwrap();

            (
                surface_state.initial_configure_sent,
                surface_state.parent.clone(),
            )
        });

        if !initial_configure_sent {
            // NOTE: This should never fail as the initial configure is always
            // allowed.
            popup.send_configure().expect("initial configure failed");
        }

        // TODO: Why do I need to access the pending state and not the current one?
        // If I access the current state, the position is always (0, 0) on the first commit.
        let position = popup.with_pending_state(|state| state.geometry.loc.into());
        let parent_id = get_surface_id(&parent?);

        Some(PopupMessage {
            parent: parent_id,
            position,
        })
    }
}

impl<BackendData: Backend> BufferHandler for ServerState<BackendData> {
    fn buffer_destroyed(&mut self, _buffer: &wl_buffer::WlBuffer) {}
}

impl<BackendData: Backend> XdgShellHandler for ServerState<BackendData> {
    fn xdg_shell_state(&mut self) -> &mut XdgShellState {
        &mut self.xdg_shell_state
    }

    fn new_toplevel(&mut self, surface: ToplevelSurface) {
        let surface_id = with_states(surface.wl_surface(), |surface_data| {
            surface_data
                .data_map
                .get::<RefCell<MySurfaceState>>()
                .unwrap()
                .borrow()
                .surface_id
        });
        self.xdg_toplevels.insert(surface_id, surface.clone());

        surface.with_pending_state(|state| {
            state.states.set(xdg_toplevel::State::Activated);
        });

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "new_toplevel",
            Some(Box::new(json!({
                "surfaceId": surface_id,
            }))),
            None,
        );
    }

    fn new_popup(&mut self, surface: PopupSurface, positioner: PositionerState) {
        surface.with_pending_state(|state| {
            state.geometry = positioner.get_geometry();
            state.positioner = positioner;
        });

        let (surface_id, parent) = with_states(surface.wl_surface(), |surface_data| {
            let surface_id = surface_data
                .data_map
                .get::<RefCell<MySurfaceState>>()
                .unwrap()
                .borrow()
                .surface_id;

            let parent = surface_data
                .data_map
                .get::<XdgPopupSurfaceData>()
                .unwrap()
                .lock()
                .unwrap()
                .parent
                .clone();

            (surface_id, parent)
        });

        self.xdg_popups.insert(surface_id, surface.clone());

        // TODO: Revise this unwrap.
        // Wayland states that popups without parents can exist but I don't know in what case.
        let parent = get_surface_id(&parent.unwrap());
        let position: MyPoint<i32, Logical> = positioner.get_geometry().loc.into();

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "new_popup",
            Some(Box::new(json!({
                "surfaceId": surface_id,
                "parent": parent,
                "position": position,
            }))),
            None,
        );
    }

    fn move_request(&mut self, surface: ToplevelSurface, _seat: WlSeat, _serial: Serial) {
        let surface_id = with_states(surface.wl_surface(), |surface_data| {
            surface_data
                .data_map
                .get::<RefCell<MySurfaceState>>()
                .unwrap()
                .borrow()
                .surface_id
        });
        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "interactive_move",
            Some(Box::new(json!({
                    "surfaceId": surface_id,
            }))),
            None,
        );
    }

    fn resize_request(
        &mut self,
        surface: ToplevelSurface,
        _seat: WlSeat,
        _serial: Serial,
        edges: ResizeEdge,
    ) {
        let surface_id = with_states(surface.wl_surface(), |surface_data| {
            surface_data
                .data_map
                .get::<RefCell<MySurfaceState>>()
                .unwrap()
                .borrow()
                .surface_id
        });
        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "interactive_resize",
            Some(Box::new(json!({
                    "surfaceId": surface_id,
                    "edge": edges as i64,
            }))),
            None,
        );
    }

    fn grab(&mut self, _surface: PopupSurface, _seat: WlSeat, _serial: Serial) {
        // Handle popup grab here
    }

    fn reposition_request(
        &mut self,
        surface: PopupSurface,
        _positioner: PositionerState,
        token: u32,
    ) {
        surface.send_repositioned(token);
    }

    fn toplevel_destroyed(&mut self, surface: ToplevelSurface) {
        let surface_id = with_states(surface.wl_surface(), |surface_data| {
            surface_data
                .data_map
                .get::<RefCell<MySurfaceState>>()
                .unwrap()
                .borrow()
                .surface_id
        });
        self.xdg_toplevels.remove(&surface_id);

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "destroy_toplevel",
            Some(Box::new(json!({
                "surfaceId": surface_id,
            }))),
            None,
        );
    }

    fn popup_destroyed(&mut self, surface: PopupSurface) {
        let surface_id = with_states(surface.wl_surface(), |surface_data| {
            surface_data
                .data_map
                .get::<RefCell<MySurfaceState>>()
                .unwrap()
                .borrow()
                .surface_id
        });
        self.xdg_popups.remove(&surface_id);

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "destroy_popup",
            Some(Box::new(json!({
                "surfaceId": surface_id,
            }))),
            None,
        );
    }
}

pub struct MySurfaceState {
    pub surface_id: u64,
    pub old_texture_size: Option<Size<i32, BufferCoords>>,
}

fn get_surface_id(surface: &WlSurface) -> u64 {
    with_states(surface, |surface_data| {
        surface_data
            .data_map
            .get::<RefCell<MySurfaceState>>()
            .unwrap()
            .borrow()
            .surface_id
    })
}

fn get_direct_subsurfaces(surface: &WlSurface) -> (Vec<u64>, Vec<u64>) {
    let mut subsurfaces_below = vec![];
    let mut subsurfaces_above = vec![];
    let mut above = false;

    with_surface_tree_upward(
        surface,
        (),
        |child_surface, _, ()| {
            // Only traverse the direct children of the surface
            if child_surface == surface {
                TraversalAction::DoChildren(())
            } else {
                TraversalAction::SkipChildren
            }
        },
        |child_surface, child_surface_data, ()| {
            if child_surface == surface {
                above = true;
                return;
            }

            let surface_id = child_surface_data
                .data_map
                .get::<RefCell<MySurfaceState>>()
                .unwrap()
                .borrow()
                .surface_id;
            if above {
                subsurfaces_above.push(surface_id);
            } else {
                subsurfaces_below.push(surface_id);
            }
        },
        |_, _, _| true,
    );
    (subsurfaces_below, subsurfaces_above)
}

impl<BackendData: Backend> CompositorHandler for ServerState<BackendData> {
    fn compositor_state(&mut self) -> &mut CompositorState {
        &mut self.compositor_state
    }

    fn client_compositor_state<'a>(&self, client: &'a Client) -> &'a CompositorClientState {
        &client.get_data::<ClientState>().unwrap().compositor_state
    }

    fn new_surface(&mut self, surface: &WlSurface) {
        let surface_id = self.get_new_surface_id();
        with_states(surface, |surface_data| {
            surface_data.data_map.insert_if_missing(|| {
                RefCell::new(MySurfaceState {
                    surface_id,
                    old_texture_size: None,
                })
            })
        });
        self.surfaces.insert(surface_id, surface.clone());

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "new_surface",
            Some(Box::new(json!({
                "surfaceId": surface_id,
            }))),
            None,
        );
    }

    fn new_subsurface(&mut self, surface: &WlSurface, parent: &WlSurface) {
        let surface_id = get_surface_id(surface);
        let parent = get_surface_id(parent);

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "new_subsurface",
            Some(Box::new(json!({
                "surfaceId": surface_id,
                "parent": parent,
            }))),
            None,
        );
    }

    fn commit(&mut self, surface: &WlSurface) {
        let (subsurfaces_below, subsurfaces_above) = get_direct_subsurfaces(surface);

        // Make sure Flutter knows about subsurfaces
        // because Wayland clients have the option to never commit them.
        // In Wayland, when the parent surface is committed,
        // subsurfaces are also committed recursively.
        for surface_id in subsurfaces_below.iter().chain(subsurfaces_above.iter()) {
            let surface = self.surfaces.get(surface_id).unwrap().clone();
            let _ = self.commit(&surface);
        }

        with_states(surface, |surface_data| {
            let (surface_id, old_texture_size) = {
                let my_state = surface_data
                    .data_map
                    .get::<RefCell<MySurfaceState>>()
                    .unwrap()
                    .borrow();
                (my_state.surface_id, my_state.old_texture_size)
            };

            let attributes = surface_data.cached_state.current::<SurfaceAttributes>();

            let texture = attributes
                .buffer
                .as_ref()
                .and_then(|assignment| match assignment {
                    BufferAssignment::NewBuffer(buffer) => self
                        .gles_renderer
                        .as_mut()
                        .unwrap()
                        .import_buffer(buffer, Some(surface_data), &[])
                        .and_then(|t| t.ok()),
                    _ => None,
                });

            let (texture_id, size) = if let Some(texture) = texture {
                unsafe {
                    self.gl.as_ref().unwrap().Finish();
                }

                let size = texture.size();

                let size_changed = match old_texture_size {
                    Some(old_size) => old_size != size,
                    None => true,
                };

                surface_data
                    .data_map
                    .get::<RefCell<MySurfaceState>>()
                    .unwrap()
                    .borrow_mut()
                    .old_texture_size = Some(size);

                let texture_id = match size_changed {
                    true => None,
                    false => self
                        .texture_ids_per_surface_id
                        .get(&surface_id)
                        .and_then(|v| v.last().cloned())
                        .map(|(id, _)| id),
                };

                let texture_id = texture_id.unwrap_or_else(|| {
                    let texture_id = self.get_new_texture_id();
                    while self
                        .texture_ids_per_surface_id
                        .entry(surface_id)
                        .or_default()
                        .len()
                        >= 2
                    {
                        self.texture_ids_per_surface_id
                            .entry(surface_id)
                            .or_default()
                            .remove(0);
                    }

                    self.texture_ids_per_surface_id
                        .entry(surface_id)
                        .or_default()
                        .push((texture_id, size));
                    self.surface_id_per_texture_id
                        .insert(texture_id, surface_id);
                    self.flutter_engine_mut()
                        .register_external_texture(texture_id)
                        .unwrap();
                    texture_id
                });

                let swapchain = self.texture_swapchains.entry(texture_id).or_default();
                swapchain.commit(texture.clone());

                self.flutter_engine_mut()
                    .mark_external_texture_frame_available(texture_id)
                    .unwrap();

                (texture_id, Some(size))
            } else {
                (-1, None)
            };

            (
                surface_id,
                texture_id,
                size,
                attributes.buffer_delta,
                attributes.buffer_scale,
                attributes.input_region.clone(),
            )
        });

        let surface_message = self.construct_surface_message(surface);

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "commit_surface",
            Some(Box::new(json!(surface_message))),
            None,
        );
    }

    fn destroyed(&mut self, _surface: &WlSurface) {
        let surface_id = with_states(_surface, |surface_data| {
            surface_data
                .data_map
                .get::<RefCell<MySurfaceState>>()
                .unwrap()
                .borrow()
                .surface_id
        });
        self.surfaces.remove(&surface_id);

        let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
        platform_method_channel.invoke_method(
            "destroy_surface",
            Some(Box::new(json!({
                "surfaceId": surface_id,
            }))),
            None,
        );
    }
}

impl<BackendData: Backend> ShmHandler for ServerState<BackendData> {
    fn shm_state(&self) -> &ShmState {
        &self.shm_state
    }
}

impl<BackendData: Backend> DmabufHandler for ServerState<BackendData> {
    fn dmabuf_state(&mut self) -> &mut DmabufState {
        self.dmabuf_state.as_mut().unwrap()
    }

    fn dmabuf_imported(
        &mut self,
        _global: &DmabufGlobal,
        _dmabuf: Dmabuf,
        notifier: ImportNotifier,
    ) {
        // TODO
        self.imported_dmabufs.push(_dmabuf);
        let _ = notifier.successful::<ServerState<BackendData>>();
    }
}

// impl DmabufHandler for ServerState<X11Data> {
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

impl<BackendData: Backend> SeatHandler for ServerState<BackendData> {
    type KeyboardFocus = WlSurface;
    type PointerFocus = WlSurface;

    fn seat_state(&mut self) -> &mut SeatState<ServerState<BackendData>> {
        &mut self.seat_state
    }

    fn focus_changed(&mut self, seat: &Seat<Self>, target: Option<&WlSurface>) {
        let dh = &self.display_handle;
        let client = target.and_then(|s| dh.get_client(s.id()).ok());
        set_data_device_focus(dh, seat, client);
    }

    fn cursor_image(&mut self, _seat: &Seat<Self>, image: CursorImageStatus) {}
}

impl<BackendData: Backend> SelectionHandler for ServerState<BackendData> {
    type SelectionUserData = ();
}

impl<BackendData: Backend> ClientDndGrabHandler for ServerState<BackendData> {}

impl<BackendData: Backend> ServerDndGrabHandler for ServerState<BackendData> {}

impl<BackendData: Backend> DataDeviceHandler for ServerState<BackendData> {
    fn data_device_state(&self) -> &DataDeviceState {
        &self.data_device_state
    }
}
