use smithay::xwayland::X11Wm;

pub mod xwayland {
    use crate::backend::Backend;
    use crate::cursor::{load_cursor_theme, Cursor};
    use crate::flutter_engine::wayland_messages::{MapX11Surface, MyPoint, NewX11Surface};
    use crate::focus::KeyboardFocusTarget;
    use crate::meta_window_state::meta_popup::{self, MetaPopup, MetaPopupPatch};
    use crate::meta_window_state::meta_resize_edge::MetaResizeEdge;
    use crate::meta_window_state::meta_window::MetaWindowPatch;
    use crate::state::State;
    use crate::wayland::wayland::get_surface_id;
    use serde_json::json;

    use smithay::input::pointer::CursorIcon;
    use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;

    use smithay::reexports::x11rb::rust_connection::{DefaultStream, RustConnection};
    use smithay::utils::{Logical, Point, Rectangle, Size, SERIAL_COUNTER};
    use smithay::wayland::seat::WaylandFocus;
    use smithay::wayland::selection::data_device::{
        clear_data_device_selection, current_data_device_selection_userdata,
        request_data_device_client_selection, set_data_device_selection,
    };
    use smithay::wayland::selection::primary_selection::{
        clear_primary_selection, current_primary_selection_userdata,
        request_primary_client_selection, set_primary_selection,
    };
    use smithay::wayland::selection::SelectionTarget;
    use smithay::wayland::xwayland_shell::{XWaylandShellHandler, XWaylandShellState};
    use smithay::xwayland::xwm::{Reorder, WmWindowProperty, XwmId};
    use smithay::xwayland::{xwm, X11Surface, X11Wm, XWayland, XWaylandEvent, XwmHandler};
    use std::borrow::Borrow;
    use std::cell::RefCell;
    use std::os::fd::OwnedFd;
    use uuid::Uuid;

    use tracing::{error, info, trace};
    pub struct MyX11SurfaceState {
        pub x11_surface_id: u64,
    }

    impl<BackendData: Backend> State<BackendData> {
        pub fn start_xwayland(data: &mut State<BackendData>) {
            use std::process::Stdio;

            //XWaylandKeyboardGrabState::new::<Self>(&self.display_handle.clone());

            let (xwayland, client) = XWayland::spawn(
                &data.display_handle,
                None,
                std::iter::empty::<(String, String)>(),
                true,
                Stdio::null(),
                Stdio::null(),
                |_| (),
            )
            .expect("failed to start XWayland");

            let ret = data
                .loop_handle
                .insert_source(xwayland, move |event, _, data| match event {
                    XWaylandEvent::Ready {
                        x11_socket,
                        display_number,
                    } => {
                        let mut wm =
                            X11Wm::start_wm(data.loop_handle.clone(), x11_socket, client.clone())
                                .expect("Failed to attach X11 Window Manager");

                        let (theme, size) = load_cursor_theme();
                        let cursor = Cursor::load(&theme, CursorIcon::Default, size);
                        let image = cursor.get_image(1, 0);
                        wm.set_cursor(
                            &image.pixels_rgba,
                            Size::from((image.width as u16, image.height as u16)),
                            Point::from((image.xhot as u16, image.yhot as u16)),
                        )
                        .expect("Failed to set xwayland default cursor");

                        data.x11_wm = Some(wm);
                        data.xwayland_display = Some(display_number);

                        if let Some(flutter_engine) = data.flutter_engine.as_mut() {
                            flutter_engine.set_environment_variable(
                                "DISPLAY",
                                Some(format!(":{}", display_number).as_str()),
                            );
                        }
                    }
                    XWaylandEvent::Error => {
                        data.x11_wm = None;
                        data.xwayland_display = None;

                        if let Some(flutter_engine) = data.flutter_engine.as_mut() {
                            flutter_engine.set_environment_variable("DISPLAY", None);
                        }
                    }
                });
            if let Err(e) = ret {
                tracing::error!(
                    "Failed to insert the XWaylandSource into the event loop: {}",
                    e
                );
            }
        }

        pub fn get_x11_surface_id(x11_surface: &X11Surface) -> u64 {
            x11_surface
                .user_data()
                .get::<RefCell<MyX11SurfaceState>>()
                .unwrap()
                .borrow()
                .x11_surface_id
        }

        fn new_x11_surface(&mut self, surface: X11Surface) {
            tracing::info!("new_x11_surface {:?}", surface.window_id());
            self.x11_surface_per_x11_window
                .insert(surface.window_id(), surface.clone());

            let x11_surface_id = self.get_new_x11_surface_id();
            surface.user_data().insert_if_missing(|| {
                RefCell::new(MyX11SurfaceState {
                    x11_surface_id: x11_surface_id,
                })
            });

            self.x11_surfaces.insert(x11_surface_id, surface.clone());
        }

        pub fn map_x11_surface(&mut self, surface: X11Surface) {
            let parent = if surface.is_override_redirect() {
                surface
                    .is_transient_for()
                    .and_then(|x11_surface| self.x11_surface_per_x11_window.get(&x11_surface))
                    // Fall back on the focused surface if the transient parent is not known.
                    .or_else(|| {
                        self.keyboard.current_focus().and_then(|focus| {
                            focus.wl_surface().and_then(|focus| {
                                self.x11_surface_per_wl_surface.get(&focus.into_owned())
                            })
                        })
                    })
                    .map(|x11_surface| Self::get_x11_surface_id(x11_surface))
            } else {
                surface
                    .is_transient_for()
                    .and_then(|x11_surface| self.x11_surface_per_x11_window.get(&x11_surface))
                    .map(|x11_surface| Self::get_x11_surface_id(&x11_surface))
            };
            info!(
                "map_x11_surface: {:?} parent: {:?}",
                Self::get_x11_surface_id(&surface),
                parent
            );
        }
    }

    impl<BackendData: Backend> XwmHandler for State<BackendData> {
        fn xwm_state(&mut self, _xwm: XwmId) -> &mut X11Wm {
            self.x11_wm.as_mut().unwrap()
        }

        fn new_window(&mut self, _xwm: XwmId, surface: X11Surface) {
            info!("X11 new_window {:?}", surface);

            let mut geometry = surface.geometry();
            geometry.loc = Point::from((0, 0));
            surface.configure(geometry).unwrap();

            self.new_x11_surface(surface);
        }

        fn new_override_redirect_window(&mut self, _xwm: XwmId, surface: X11Surface) {
            info!("X11 new_override_redirect_window {:?}", surface);
            self.new_x11_surface(surface);
        }

        fn map_window_request(&mut self, _xwm: XwmId, surface: X11Surface) {
            surface.set_mapped(true).unwrap();
            surface.set_activated(true).unwrap();
        }

        fn map_window_notify(&mut self, _xwm: XwmId, surface: X11Surface) {
            self.map_x11_surface(surface);
        }

        fn mapped_override_redirect_window(&mut self, _xwm: XwmId, surface: X11Surface) {
            self.map_x11_surface(surface.clone());
            surface.set_activated(true).unwrap();
        }

        fn unmapped_window(&mut self, _: XwmId, surface: X11Surface) {
            let Some(wl_surface) = surface.wl_surface() else {
                return;
            };

            self.x11_surface_per_wl_surface.remove(&wl_surface);

            let x11_surface_id = Self::get_x11_surface_id(&surface);
            let surface_id = get_surface_id(&wl_surface);
            if surface.is_override_redirect() {
                if let Some(meta_popup_id) = self
                    .meta_window_state
                    .meta_popup_id_per_surface_id
                    .remove(&surface_id)
                {
                    self.remove_meta_popup(&meta_popup_id);
                }
            } else {
                if let Some(meta_window) = self.get_meta_window(surface_id) {
                    self.remove_meta_window(&meta_window.id);
                }
            }

            if !surface.is_override_redirect() {
                surface.set_mapped(false).unwrap();
            }
        }

        fn destroyed_window(&mut self, _xwm: XwmId, surface: X11Surface) {
            let x11_surface_id = Self::get_x11_surface_id(&surface);

            self.x11_surface_per_x11_window.remove(&surface.window_id());
            self.x11_surfaces.remove(&x11_surface_id);
        }

        fn configure_request(
            &mut self,
            _xwm: XwmId,
            window: X11Surface,
            _x: Option<i32>,
            _y: Option<i32>,
            w: Option<u32>,
            h: Option<u32>,
            _reorder: Option<Reorder>,
        ) {
            // We just set the new size, but don't let windows move themselves around freely.
            let mut geo = window.geometry();
            geo.loc = Point::from((0, 0));
            if let Some(w) = w {
                geo.size.w = w as i32;
            }
            if let Some(h) = h {
                geo.size.h = h as i32;
            }
            let _ = window.configure(geo);
        }

        fn configure_notify(
            &mut self,
            _xwm: XwmId,
            x11_surface: X11Surface,
            geometry: Rectangle<i32, Logical>,
            _above: Option<u32>,
        ) {
            info!("configure_notify: {:?}", geometry);
            let surface_id = Self::get_x11_surface_id(&x11_surface);
            if x11_surface.is_override_redirect() && x11_surface.wl_surface().is_some() {
                if let Some(meta_popup_id) = self
                    .meta_window_state
                    .meta_popup_id_per_surface_id
                    .get(&get_surface_id(&x11_surface.wl_surface().unwrap()))
                    .cloned()
                {
                    self.patch_meta_popup(MetaPopupPatch::UpdatePosition {
                        id: meta_popup_id,
                        value: geometry.loc.into(),
                    });
                }
            }
            if let Some(meta_window) = self.get_meta_window(surface_id) {
                self.patch_meta_window(
                    MetaWindowPatch::UpdateGeometry {
                        id: meta_window.id,
                        value: Some(geometry.into()),
                    },
                    true,
                );
            }
        }

        fn property_notify(
            &mut self,
            _xwm: XwmId,
            x11_surface: X11Surface,
            property: WmWindowProperty,
        ) {
            info!("property_notify: {:?}", property);
            let surface_id = Self::get_x11_surface_id(&x11_surface);
            if let Some(meta_window) = self.get_meta_window(surface_id) {
                match property {
                    WmWindowProperty::Title => {
                        let title = x11_surface.title();
                        let title = if !title.is_empty() { Some(title) } else { None };
                        info!("title changed: {:?}", title);
                        self.patch_meta_window(
                            MetaWindowPatch::UpdateTitle {
                                id: meta_window.id,
                                value: title,
                            },
                            true,
                        );
                    }
                    WmWindowProperty::Pid => {
                        let pid = x11_surface.pid().unwrap_or(0);
                        info!("pid changed: {}", pid);
                        self.patch_meta_window(
                            MetaWindowPatch::UpdatePid {
                                id: meta_window.id,
                                value: pid as i32,
                            },
                            true,
                        );
                    }
                    WmWindowProperty::Class => {
                        let class = x11_surface.class();
                        info!("class changed: {}", class);
                    }
                    WmWindowProperty::TransientFor => {
                        let transient_for = x11_surface.is_transient_for();
                        info!("transient_for changed: {:?}", transient_for);
                    }
                    WmWindowProperty::MotifHints => {
                        let hints = x11_surface.size_hints();
                        info!("motif_hints changed: {:?}", hints);
                    }

                    _ => {}
                }
            }
        }

        fn resize_request(
            &mut self,
            _xwm: XwmId,
            x11_surface: X11Surface,
            _button: u32,
            resize_edge: xwm::ResizeEdge,
        ) {
            print!("resize_request");
            let surface_id = get_surface_id(&x11_surface.wl_surface().unwrap());
            let meta_window = self.get_meta_window(surface_id).unwrap();
            let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
            let resize_edge = MetaResizeEdge::from(resize_edge);

            platform_method_channel.invoke_method(
                "interactive_resize",
                Some(Box::new(json!({
                    "metaWindowId": meta_window.id,
                    "edge": resize_edge.bits()
                    ,
                }))),
                None,
            );

            /* let pointer = self.seat.get_pointer().unwrap();
            pointer.unset_grab(
                self,
                SERIAL_COUNTER.next_serial(),
                self.clock.now().as_millis() as u32,
            ); */
        }

        fn move_request(&mut self, _xwm: XwmId, x11_surface: X11Surface, _button: u32) {
            print!("move_request");
            let surface_id = get_surface_id(&x11_surface.wl_surface().unwrap());
            let meta_window = self.get_meta_window(surface_id).unwrap();
            let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
            platform_method_channel.invoke_method(
                "interactive_move",
                Some(Box::new(json!({
                        "metaWindowId": meta_window.id,
                }))),
                None,
            );
        }

        fn allow_selection_access(&mut self, xwm: XwmId, _selection: SelectionTarget) -> bool {
            if let Some(keyboard) = self.seat.get_keyboard() {
                // check that an X11 window is focused
                if let Some(KeyboardFocusTarget::X11Surface(surface)) = keyboard.current_focus() {
                    if surface.xwm_id().unwrap() == xwm {
                        return true;
                    }
                }
            }
            false
        }

        fn send_selection(
            &mut self,
            _xwm: XwmId,
            selection: SelectionTarget,
            mime_type: String,
            fd: OwnedFd,
        ) {
            match selection {
                SelectionTarget::Clipboard => {
                    if let Err(err) =
                        request_data_device_client_selection(&self.seat, mime_type, fd)
                    {
                        error!(
                            ?err,
                            "Failed to request current wayland clipboard for Xwayland",
                        );
                    }
                }
                SelectionTarget::Primary => {
                    if let Err(err) = request_primary_client_selection(&self.seat, mime_type, fd) {
                        error!(
                            ?err,
                            "Failed to request current wayland primary selection for Xwayland",
                        );
                    }
                }
            }
        }

        fn new_selection(
            &mut self,
            _xwm: XwmId,
            selection: SelectionTarget,
            mime_types: Vec<String>,
        ) {
            trace!(?selection, ?mime_types, "Got Selection from X11",);
            // TODO check, that focused windows is X11 window before doing this
            match selection {
                SelectionTarget::Clipboard => {
                    set_data_device_selection(&self.display_handle, &self.seat, mime_types, ())
                }
                SelectionTarget::Primary => {
                    set_primary_selection(&self.display_handle, &self.seat, mime_types, ())
                }
            }
        }

        fn cleared_selection(&mut self, _xwm: XwmId, selection: SelectionTarget) {
            match selection {
                SelectionTarget::Clipboard => {
                    if current_data_device_selection_userdata(&self.seat).is_some() {
                        clear_data_device_selection(&self.display_handle, &self.seat)
                    }
                }
                SelectionTarget::Primary => {
                    if current_primary_selection_userdata(&self.seat).is_some() {
                        clear_primary_selection(&self.display_handle, &self.seat)
                    }
                }
            }
        }

        fn fullscreen_request(&mut self, _xwm: XwmId, window: X11Surface) {
            let geometry = window.geometry();

            info!("is_fullscreen {:?}", window.is_fullscreen());
            window.set_fullscreen(true).unwrap();
            window.configure(geometry).unwrap();
        }
        fn unfullscreen_request(&mut self, _xwm: XwmId, window: X11Surface) {
            info!("unfullscreen_request");
            window.set_fullscreen(false).unwrap();
        }
        fn maximize_request(&mut self, _xwm: XwmId, window: X11Surface) {
            info!("maximize_request");
            window.set_maximized(true).unwrap();
        }
        fn unmaximize_request(&mut self, _xwm: XwmId, window: X11Surface) {
            info!("unmaximize_request");
            window.set_maximized(false).unwrap();
        }
    }

    impl<BackendData: Backend> XWaylandShellHandler for State<BackendData> {
        fn xwayland_shell_state(&mut self) -> &mut XWaylandShellState {
            &mut self.xwayland_shell_state
        }

        fn surface_associated(&mut self, _xwm: XwmId, wl_surface: WlSurface, surface: X11Surface) {
            let x11_surface_id = Self::get_x11_surface_id(&surface);
            self.x11_surface_per_wl_surface
                .insert(wl_surface.clone(), surface.clone());
            info!(
                "Associating X11 surface {:?} with wl_surface {:?}",
                x11_surface_id, wl_surface
            );
            let parent_surface = surface
                .is_transient_for()
                .and_then(|parent_window| self.x11_surface_per_x11_window.get(&parent_window));

            let mapped_id = surface.mapped_window_id();
            info!("mapped_id: {:?}", mapped_id);
            let hints = surface.hints();
            info!("hints: {:?}", hints);
            if surface.is_override_redirect() {
                if let Some(parent_meta_window_id) = parent_surface
                    .and_then(|parent_surface| {
                        parent_surface.wl_surface().and_then(|parent_surface| {
                            self.meta_window_state
                                .meta_window_id_per_surface_id
                                .get(&get_surface_id(&parent_surface))
                        })
                    })
                    .or_else(|| {
                        self.keyboard.current_focus().and_then(|focus| {
                            focus.wl_surface().and_then(|focus| {
                                self.x11_surface_per_wl_surface
                                    .get(&focus.into_owned())
                                    .and_then(|parent_surface| {
                                        parent_surface.wl_surface().and_then(|parent_surface| {
                                            self.meta_window_state
                                                .meta_window_id_per_surface_id
                                                .get(&get_surface_id(&(parent_surface)))
                                        })
                                    })
                            })
                        })
                    })
                {
                    let meta_popup = self.create_meta_popup(MetaPopup {
                        id: Uuid::new_v4().hyphenated().to_string(),
                        position: surface.geometry().loc.into(),
                        parent: parent_meta_window_id.clone(),
                        surface_id: get_surface_id(wl_surface.borrow()),
                    });
                    self.meta_window_state
                        .meta_popup_id_per_surface_id
                        .insert(get_surface_id(wl_surface.borrow()), meta_popup.id);
                }
            } else {
                let meta_window = self.new_meta_window_for_x11_surface(
                    surface.clone(),
                    get_surface_id(wl_surface.borrow()),
                    parent_surface.and_then(|parent_x11_surface| {
                        info!("parent_x11_surface: {:?}", parent_x11_surface);
                        info!(
                            "parent_x11_surface.wl_surface(): {:?}",
                            parent_x11_surface.wl_surface()
                        );
                        parent_x11_surface
                            .wl_surface()
                            .and_then(|parent_surface| Some(get_surface_id(&parent_surface)))
                            .or_else(|| {
                                self.keyboard.current_focus().and_then(|focus| {
                                    focus.wl_surface().and_then(|focus_surface| {
                                        self.x11_surface_per_wl_surface
                                            .get(&focus_surface.into_owned())
                                            .and_then(|parent_surface| {
                                                parent_surface.wl_surface().map(|parent_surface| {
                                                    get_surface_id(&(parent_surface))
                                                })
                                            })
                                    })
                                })
                            })
                    }),
                );
                self.meta_window_state
                    .meta_window_id_per_surface_id
                    .insert(get_surface_id(wl_surface.borrow()), meta_window.id);
            }
        }
    }
}
