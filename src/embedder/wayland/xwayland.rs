use smithay::xwayland::X11Wm;

pub mod xwayland {
    use crate::backend::Backend;
    use crate::capture::selection::{send_native_selection, NATIVE_SCREENSHOT_MIME, PNG_MIME};
    use crate::cursor::{load_cursor_theme, Cursor};
    use crate::flutter_engine::wayland_messages::{MapX11Surface, MyPoint, NewX11Surface};
    use crate::focus::{KeyboardFocusTarget, PointerFocusTarget};
    use crate::meta_window_state::floating_move::clamp_position;
    use crate::meta_window_state::meta_popup::{
        self, MetaPopup, MetaPopupCategory, MetaPopupPatch,
    };
    use crate::meta_window_state::meta_resize_edge::MetaResizeEdge;
    use crate::meta_window_state::meta_window::MetaWindowPatch;
    use crate::state::State;
    use crate::wayland::wayland::get_surface_id;
    use serde_json::json;
    use smithay::backend::allocator::Fourcc;
    use smithay::backend::renderer::element::memory::{
        MemoryRenderBuffer, MemoryRenderBufferRenderElement,
    };
    use smithay::backend::renderer::element::Kind;
    use smithay::backend::renderer::pixman::{PixmanError, PixmanRenderer};
    use smithay::backend::renderer::utils::draw_render_elements;
    use smithay::backend::renderer::{Bind, Frame, Offscreen, Renderer};
    use smithay::input::pointer::CursorIcon;
    use smithay::reexports::gbm::Format;
    use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;

    use smithay::reexports::wayland_server::Client;
    use smithay::reexports::x11rb::rust_connection::{DefaultStream, RustConnection};
    use smithay::utils::{
        Buffer as BufferCoords, Logical, Point, Rectangle, Size, Transform, SERIAL_COUNTER,
    };
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
    use smithay::xwayland::xwm::{Reorder, WmWindowProperty, WmWindowType, XwmId};
    use smithay::xwayland::{
        xwm, X11Surface, X11Wm, XWayland, XWaylandClientData, XWaylandEvent, XwmHandler,
    };
    use std::borrow::Borrow;
    use std::cell::RefCell;
    use std::os::fd::OwnedFd;
    use uuid::Uuid;
    use xcursor::parser::Image;

    use tracing::{error, info, trace, warn};

    pub struct XWaylandState {
        pub client: Client,
        pub xwm: Option<X11Wm>,
        pub display: u32,
    }

    impl XWaylandState {
        pub fn reload_cursor(&mut self, scale: f64) {
            if let Some(wm) = self.xwm.as_mut() {
                let (theme, size) = load_cursor_theme();
                let cursor = Cursor::load(&theme, CursorIcon::Default, size);
                let image = cursor.get_image(scale.ceil() as u32, 0);

                let (pixels_rgba, size, hotspot) = match scale_cursor(scale, size, &image) {
                    Ok(x) => x,
                    Err(err) => {
                        warn!("Failed to scale Xwayland cursor image: {}", err);
                        (
                            image.pixels_rgba,
                            Size::from((image.width as u16, image.height as u16)),
                            Point::from((image.xhot as u16, image.yhot as u16)),
                        )
                    }
                };

                if let Err(err) = wm.set_cursor(&pixels_rgba, size, hotspot) {
                    warn!(
                        id = ?wm.id(),
                        ?err,
                        "Failed to set default cursor for Xwayland WM",
                    );
                }
            }
        }
    }

    fn scale_cursor(
        scale: f64,
        cursor_size: u32,
        image: &Image,
    ) -> Result<(Vec<u8>, Size<u16, Logical>, Point<u16, Logical>), PixmanError> {
        let mut renderer = PixmanRenderer::new()?;
        let image_scale = (image.size / cursor_size).max(1);
        let pixel_size = (cursor_size as f64 * scale).round() as i32;
        let buffer_size = Size::<i32, BufferCoords>::from((pixel_size, pixel_size));
        let output_size = buffer_size.to_logical(1, Transform::Normal).to_physical(1);

        let image_buffer = MemoryRenderBuffer::from_slice(
            &image.pixels_rgba,
            Fourcc::Abgr8888,
            (image.width as i32, image.height as i32),
            image_scale as i32,
            Transform::Normal,
            None,
        );
        let element = MemoryRenderBufferRenderElement::from_buffer(
            &mut renderer,
            (0., 0.),
            &image_buffer,
            None,
            None,
            None,
            Kind::Unspecified,
        )?;

        let mut buffer = renderer.create_buffer(Fourcc::Abgr8888, buffer_size)?;
        let mut fb = renderer.bind(&mut buffer)?;
        let mut frame = renderer.render(&mut fb, output_size, Transform::Normal)?;
        draw_render_elements(
            &mut frame,
            scale,
            &[element],
            &[Rectangle::new((0, 0).into(), output_size)],
        )?;
        let sync = frame.finish()?;
        while let Err(_) = sync.wait() {}

        let len = (buffer_size.w * buffer_size.h * 4) as usize;
        let mut data = Vec::with_capacity(len);
        assert_eq!(buffer.stride(), (buffer_size.w * 4) as usize);
        data.extend_from_slice(unsafe {
            std::slice::from_raw_parts(buffer.data() as *mut u8, len)
        });

        let hotspot = Point::<i32, BufferCoords>::from((image.xhot as i32, image.yhot as i32))
            .to_f64()
            .to_logical(
                image_scale as f64,
                Transform::Normal,
                &Size::from((image.width as f64, image.height as f64)),
            )
            .to_buffer(
                scale,
                Transform::Normal,
                &output_size.to_logical(1).to_f64(),
            )
            .to_i32_round::<i32>();
        Ok((
            data,
            Size::from((buffer_size.w as u16, buffer_size.h as u16)),
            Point::from((hotspot.x as u16, hotspot.y as u16)),
        ))
    }

    pub struct MyX11SurfaceState {
        pub x11_surface_id: u64,
    }

    /// X11 clients use override-redirect windows for several different roles.
    /// Keep the distinction in the model instead of making Flutter guess from
    /// a size or an application title.
    fn x11_popup_category(
        surface: &X11Surface,
        geometry: Rectangle<i32, Logical>,
    ) -> MetaPopupCategory {
        match surface.window_type() {
            Some(
                WmWindowType::Menu
                | WmWindowType::PopupMenu
                | WmWindowType::DropdownMenu
                | WmWindowType::Combo,
            ) => return MetaPopupCategory::Menu,
            _ => {}
        }

        // A one-pixel window is a backing/preview window, never visible UI. A
        // non-interactive override-redirect window is likewise bookkeeping-only
        // for the shell; the client cannot receive pointer input through it.
        let is_tiny = geometry.size.w <= 1 || geometry.size.h <= 1;
        let is_non_interactive = surface.hints().and_then(|hints| hints.input) == Some(false);
        if is_tiny || is_non_interactive {
            return MetaPopupCategory::Helper;
        }

        match surface.window_type() {
            Some(WmWindowType::Tooltip) => MetaPopupCategory::Tooltip,
            _ => MetaPopupCategory::Popup,
        }
    }

    impl<BackendData: Backend> State<BackendData> {
        pub fn start_xwayland(data: &mut State<BackendData>) {
            use std::process::Stdio;

            //XWaylandKeyboardGrabState::new::<Self>(&self.display_handle.clone());

            let (xwayland, client) = XWayland::spawn(
                &data.display_handle,
                None,
                std::iter::empty::<(String, String)>(),
                std::iter::empty::<String>(),
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
                        data.xwayland_state = Some(XWaylandState {
                            client: client.clone(),
                            xwm: None,
                            display: display_number,
                        });
                        let wm = X11Wm::start_wm(
                            data.loop_handle.clone(),
                            &data.display_handle,
                            x11_socket,
                            client.clone(),
                        )
                        .expect("Failed to attach X11 Window Manager");
                        data.xwayland_state.as_mut().unwrap().xwm = Some(wm);
                        // Xwayland starts lazily, after `on_outputs_changed`
                        // already ran, so the X toolkit settings (cursor size,
                        // DPI, client scale) were never applied. Without them
                        // the first X client falls back to its own defaults,
                        // which on a multi-monitor setup made it use a 2x
                        // cursor until an output change re-applied the scale.
                        let highest_scale = data
                            .space
                            .outputs()
                            .map(|output| output.current_scale().fractional_scale())
                            .fold(f64::NAN, f64::max);
                        let highest_scale = if highest_scale.is_nan() {
                            1.0
                        } else {
                            highest_scale
                        };
                        data.update_xwayland_scale(highest_scale);

                        std::env::set_var("DISPLAY", format!(":{}", display_number));
                        if let Some(flutter_engine) = data.flutter_engine.as_mut() {
                            flutter_engine.set_environment_variable(
                                "DISPLAY",
                                Some(format!(":{}", display_number).as_str()),
                            );
                        }
                    }
                    XWaylandEvent::Error => {
                        data.xwayland_state = None;
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

        pub fn update_xwayland_scale(&mut self, new_scale: f64) {
            if let Some(xwayland) = self.xwayland_state.as_mut() {
                let geometries = self
                    .x11_surfaces
                    .iter()
                    .filter_map(|s| Some((s.1.clone(), s.1.geometry())))
                    .collect::<Vec<_>>();

                let cursor_size = std::env::var("XCURSOR_SIZE")
                    .ok()
                    .and_then(|s| s.parse().ok())
                    .unwrap_or(24);

                // update xorg dpi
                if let Some(xwm) = xwayland.xwm.as_mut() {
                    let dpi = new_scale * 96. * 1024.;
                    if let Err(err) = xwm.set_xsettings(
                        [
                            ("Xft/DPI".into(), (dpi.round() as i32).into()),
                            (
                                "Xcursor/size".into(),
                                ((new_scale * cursor_size as f64).round() as i32).into(),
                            ),
                            (
                                "Gdk/UnscaledDPI".into(),
                                ((dpi / new_scale).round() as i32).into(),
                            ),
                            (
                                "Gdk/WindowScalingFactor".into(),
                                (new_scale.round() as i32).into(),
                            ),
                            (
                                "Gtk/CursorThemeSize".into(),
                                ((new_scale * cursor_size as f64).round() as i32).into(),
                            ),
                        ]
                        .into_iter(),
                    ) {
                        warn!(wm_id = ?xwm.id(), ?err, "Failed to update XSETTINGS.");
                    }
                }

                // update cursor
                xwayland.reload_cursor(new_scale);

                // update client scale
                xwayland
                    .client
                    .get_data::<XWaylandClientData>()
                    .unwrap()
                    .compositor_state
                    .set_client_scale(new_scale);

                /* // update wl/xdg_outputs
                for output in self.space.outputs() {
                    output.change_current_state(None, None, None, None);
                } */

                // update geometries
                for (surface, geometry) in geometries.iter() {
                    if let Err(err) = surface.configure(*geometry) {
                        warn!(?err, surface = ?surface.window_id(), "Failed to update geometry after scale change");
                    }
                }
            }
        }
    }

    impl<BackendData: Backend> XwmHandler for State<BackendData> {
        fn xwm_state(&mut self, _xwm: XwmId) -> &mut X11Wm {
            self.xwayland_state
                .as_mut()
                .and_then(|state| state.xwm.as_mut())
                .unwrap()
        }

        fn new_window(&mut self, _xwm: XwmId, surface: X11Surface) {
            info!("X11 new_window {:?}", surface);

            // Keep the legacy tiled placement at the X11 origin. Honouring an
            // ICCCM position hint here would change every X11 window at
            // launch, including tiled/maximized ones whose override-redirect
            // popups are rendered against the origin. A floating window
            // recovers its own placement from the client's configure requests
            // once the floating tile owns it.
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

            let surface_id = get_surface_id(&wl_surface);
            if surface.is_override_redirect() {
                if let Some(meta_popup_id) = self
                    .meta_window_state
                    .meta_popup_id_per_surface_id
                    .remove(&surface_id)
                {
                    self.remove_meta_popup(&meta_popup_id);
                }
            } else if let Some(meta_window) = self.get_meta_window(surface_id) {
                self.remove_meta_window(&meta_window.id);
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
            x: Option<i32>,
            y: Option<i32>,
            w: Option<u32>,
            h: Option<u32>,
            _reorder: Option<Reorder>,
        ) {
            // Windows may not move themselves while the shell tiles them. A
            // floating window is different: clients place their own panels and
            // auxiliary windows at explicit coordinates, and the shell draws
            // them there. `display_mode` is the placement authority;
            // `None` means "not routed yet" and stays on the legacy tiled
            // path.
            let meta_window = window
                .wl_surface()
                .and_then(|surface| self.get_meta_window(get_surface_id(&surface)));
            let can_position = meta_window.as_ref().is_some_and(|mw| mw.is_floating());
            if let Some(meta_window) = meta_window.as_ref() {
                // Only a configure accepted for a floating window is an
                // explicit floating placement. Tiled/launch configures at
                // (0,0) used to mark the window explicit before the viewport
                // existed, so the window was pinned to the tile origin instead
                // of being centred once it entered a floating tile.
                if can_position && !meta_window.position_explicit && (x.is_some() || y.is_some()) {
                    self.patch_meta_window(
                        MetaWindowPatch::UpdatePositionExplicit {
                            id: meta_window.id.clone(),
                            value: true,
                        },
                        true,
                    );
                }
            }
            tracing::debug!(
                target: "veshell::geometry",
                window = ?window.window_id(),
                meta_window = ?meta_window.as_ref().map(|mw| mw.id.as_str()),
                requested = ?(x, y, w, h),
                can_position,
                "configure_request"
            );

            // The size still comes from the surface-local geometry (as
            // before); only the location is a root position. Starting from
            // `last_configure` preserves the current root position for
            // size-only requests instead of resetting it to (0, 0).
            let mut geo = window.geometry();
            if can_position {
                geo.loc = window.last_configure().loc;
                if let Some(x) = x {
                    geo.loc.x = x;
                }
                if let Some(y) = y {
                    geo.loc.y = y;
                }
            } else {
                geo.loc = Point::from((0, 0));
            }
            if let Some(w) = w {
                geo.size.w = w as i32;
            }
            if let Some(h) = h {
                geo.size.h = h as i32;
            }
            if can_position {
                if let Some(rect) = meta_window
                    .as_ref()
                    .and_then(|meta_window| meta_window.viewport.as_ref())
                    .filter(|rect| rect.0.size.w > 0 && rect.0.size.h > 0)
                {
                    // A floating client may only position itself inside the tile.
                    // Clamping here keeps the native position and the rendered
                    // box identical for client-driven panel moves too.
                    let clamped = clamp_position(
                        rect.0,
                        Size::from((geo.size.w, geo.size.h)),
                        Point::from((f64::from(geo.loc.x), f64::from(geo.loc.y))),
                    );
                    geo.loc = Point::from((clamped.x.round() as i32, clamped.y.round() as i32));
                    tracing::debug!(
                        target: "veshell::geometry",
                        meta_window_id = %meta_window.as_ref().map(|mw| mw.id.as_str()).unwrap_or(""),
                        requested_loc = ?(x, y),
                        effective_loc = ?geo.loc,
                        viewport = ?rect,
                        size = ?geo.size,
                        "clamped floating configure_request"
                    );
                } else if let Some(meta_window) = meta_window.as_ref() {
                    tracing::debug!(
                        target: "veshell::geometry",
                        meta_window_id = %meta_window.id,
                        requested_loc = ?(x, y),
                        effective_loc = ?geo.loc,
                        "floating configure_request without a viewport rect"
                    );
                }
            }
            let configured_loc = geo.loc;
            let _ = window.configure(geo);
            if can_position {
                if let Some(meta_window) = meta_window.as_ref() {
                    // Update the authoritative position immediately instead of
                    // waiting for ConfigureNotify. The client's next XMoveWindow
                    // can arrive before that event; a stale position would make
                    // the pointer basis trail the client's own drag and feed the
                    // movement back into it.
                    self.patch_meta_window(
                        MetaWindowPatch::UpdatePosition {
                            id: meta_window.id.clone(),
                            value: Some(configured_loc.into()),
                        },
                        true,
                    );
                    self.update_floating_pointer_basis(
                        meta_window,
                        (f64::from(configured_loc.x), f64::from(configured_loc.y)).into(),
                    );
                }
            }
        }

        fn configure_notify(
            &mut self,
            _xwm: XwmId,
            x11_surface: X11Surface,
            geometry: Rectangle<i32, Logical>,
            _above: Option<u32>,
        ) {
            info!("configure_notify: {:?}", geometry);
            let Some(wl_surface) = x11_surface.wl_surface() else {
                return;
            };
            let surface_id = get_surface_id(&wl_surface);

            if x11_surface.is_override_redirect() {
                if let Some(meta_popup_id) = self
                    .meta_window_state
                    .meta_popup_id_per_surface_id
                    .get(&surface_id)
                    .cloned()
                {
                    let parent_meta_window_id = self
                        .meta_window_state
                        .meta_popups
                        .get(&meta_popup_id)
                        .map(|popup| popup.parent.clone());
                    let position = parent_meta_window_id
                        .as_deref()
                        .and_then(|parent| {
                            self.meta_window_state
                                .x11_popup_tile_position(parent, geometry.loc)
                        })
                        .unwrap_or_else(|| {
                            let tile_origin = parent_meta_window_id
                                .as_deref()
                                .and_then(|parent| {
                                    self.meta_window_state.tile_content_origin(parent)
                                })
                                .unwrap_or_else(|| Point::from((0, 0)));
                            geometry.loc - tile_origin
                        });
                    let previous = self
                        .meta_window_state
                        .meta_popups
                        .get(&meta_popup_id)
                        .map(|popup| popup.position.0);
                    self.patch_meta_popup(
                        MetaPopupPatch::UpdatePosition {
                            id: meta_popup_id.clone(),
                            value: position.into(),
                        },
                        true,
                    );
                    if let Some(popup) = self.meta_window_state.meta_popups.get_mut(&meta_popup_id)
                    {
                        popup.native_root = Some(geometry.loc.into());
                    }
                    if let Some(previous) = previous {
                        self.translate_pointer_focus_offset_for_surface(
                            surface_id,
                            f64::from(position.x - previous.x),
                            f64::from(position.y - previous.y),
                        );
                    }
                    if let Some(popup) = self.meta_window_state.meta_popups.get(&meta_popup_id) {
                        let parent = self.meta_window_state.meta_windows.get(&popup.parent);
                        tracing::debug!(
                            target: "veshell::popup_drag",
                            popup_id = %meta_popup_id,
                            surface_id,
                            root_geometry = ?geometry,
                            popup_position = ?popup.position.0,
                            parent_id = %popup.parent,
                            parent_position = ?parent.and_then(|w| w.position.as_ref().map(|p| p.0)),
                            parent_render_origin = ?parent.and_then(|w| w.render_origin.as_ref().map(|p| p.0)),
                            parent_surface_origin = ?parent.and_then(|w| w.surface_origin()),
                            parent_floating = ?parent.map(|w| w.is_floating()),
                            model_origin = ?self.meta_window_state.popup_surface_origin(popup),
                            pointer = ?self.pointer.current_location(),
                            focus = ?self.pointer_focus.as_ref().map(|(target, offset)| (
                                target.wl_surface().map(|surface| get_surface_id(&surface)),
                                *offset,
                            )),
                            buttons = self.flutter_engine().mouse_button_tracker.are_any_buttons_pressed(),
                            grab_owner = ?self.popup_pointer_grab.map(|grab| grab.surface_id),
                            "popup_drag_configure"
                        );
                    }
                    if self
                        .popup_pointer_grab
                        .is_some_and(|grab| grab.surface_id == surface_id)
                    {
                        if let (Some(popup), Some(surface)) = (
                            self.meta_window_state.meta_popups.get(&meta_popup_id),
                            self.surfaces.get(&surface_id).cloned(),
                        ) {
                            if let Some(origin) = self.meta_window_state.popup_surface_origin(popup)
                            {
                                self.pointer_focus =
                                    Some((PointerFocusTarget::from(&surface), origin));
                            }
                        }
                    }
                    // Override-redirect menus/toolbars often grab the pointer
                    // while dragging themselves. The configure delta above has
                    // already translated the focused popup's basis; do not
                    // overwrite it with a model-derived origin while the drag
                    // is active, or the client feeds that movement back into
                    // its own position.
                }
            }
            if let Some(meta_window) = self.get_meta_window(surface_id) {
                let skip_taskbar = x11_surface.is_skip_taskbar();
                if meta_window.skip_taskbar != skip_taskbar {
                    self.patch_meta_window(
                        MetaWindowPatch::UpdateSkipTaskbar {
                            id: meta_window.id.clone(),
                            value: skip_taskbar,
                        },
                        true,
                    );
                }
                let keep_on_top = x11_surface.is_above();
                if meta_window.keep_on_top != keep_on_top {
                    self.patch_meta_window(
                        MetaWindowPatch::UpdateKeepOnTop {
                            id: meta_window.id.clone(),
                            value: keep_on_top,
                        },
                        true,
                    );
                }
                // ConfigureNotify carries the root-window position; keep that
                // separate from the surface-local geometry the shell renders.
                //
                // A floating client can reach this path with a position outside
                // its tile: XMoveWindow does not necessarily go through
                // configure_request (and a stale/missing viewport rect would
                // make the request path a no-op). Correct the native window
                // here as well, otherwise the Flutter box is clamped to the
                // tile while the X11 window stays outside and pointer events
                // are offset from what the user sees.
                let mut root_position = geometry.loc;
                // A ConfigureNotify caused by our own compositor configure must
                // not undo a move/resize gesture: those gestures use the
                // half-outside move clamp. Client-initiated XMoveWindow still
                // goes through the strict clamp in configure_request.
                let gesture_active =
                    self.floating_move.as_ref().is_some_and(|move_| {
                        move_.meta_window_id.as_str() == meta_window.id.as_str()
                    }) || self.floating_resize.as_ref().is_some_and(|resize| {
                        resize.meta_window_id.as_str() == meta_window.id.as_str()
                    });
                if meta_window.is_floating()
                    && !meta_window.client_maximized
                    && !gesture_active
                    && geometry.size.w > 0
                    && geometry.size.h > 0
                {
                    if let Some(rect) = meta_window
                        .viewport
                        .as_ref()
                        .filter(|rect| rect.0.size.w > 0 && rect.0.size.h > 0)
                    {
                        let clamped = clamp_position(
                            rect.0,
                            geometry.size,
                            Point::from((f64::from(geometry.loc.x), f64::from(geometry.loc.y))),
                        );
                        let clamped_loc =
                            Point::from((clamped.x.round() as i32, clamped.y.round() as i32));
                        if clamped_loc != geometry.loc {
                            let mut configure = x11_surface.last_configure();
                            configure.loc = clamped_loc;
                            if configure.size.w <= 0 || configure.size.h <= 0 {
                                // A ConfigureNotify can arrive before the
                                // first real configure size is cached. Using
                                // that zero size would hide the window.
                                configure.size = geometry.size;
                            }
                            tracing::info!(
                                target: "veshell::geometry",
                                meta_window_id = %meta_window.id,
                                observed_loc = ?geometry.loc,
                                corrected_loc = ?clamped_loc,
                                viewport = ?rect,
                                size = ?configure.size,
                                "correcting out-of-tile floating configure_notify"
                            );
                            let _ = x11_surface.configure(configure);
                            root_position = clamped_loc;
                        }
                    } else {
                        tracing::debug!(
                            target: "veshell::geometry",
                            meta_window_id = %meta_window.id,
                            observed_loc = ?geometry.loc,
                            "floating configure_notify without a viewport rect"
                        );
                    }
                }
                self.patch_meta_window(
                    MetaWindowPatch::UpdatePosition {
                        id: meta_window.id.clone(),
                        value: Some(root_position.into()),
                    },
                    true,
                );
                self.update_floating_pointer_basis(
                    &meta_window,
                    (f64::from(root_position.x), f64::from(root_position.y)).into(),
                );
                let mut surface_geometry = x11_surface.geometry();
                if surface_geometry.size.w <= 0 || surface_geometry.size.h <= 0 {
                    surface_geometry = Rectangle::from_size(geometry.size);
                }
                self.patch_meta_window(
                    MetaWindowPatch::UpdateGeometry {
                        id: meta_window.id,
                        value: Some(surface_geometry.into()),
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
            let Some(wl_surface) = x11_surface.wl_surface() else {
                return;
            };

            let surface_id = get_surface_id(&wl_surface);
            if let Some(meta_window) = self.get_meta_window(surface_id) {
                let skip_taskbar = x11_surface.is_skip_taskbar();
                if meta_window.skip_taskbar != skip_taskbar {
                    self.patch_meta_window(
                        MetaWindowPatch::UpdateSkipTaskbar {
                            id: meta_window.id.clone(),
                            value: skip_taskbar,
                        },
                        true,
                    );
                }
                let keep_on_top = x11_surface.is_above();
                if meta_window.keep_on_top != keep_on_top {
                    self.patch_meta_window(
                        MetaWindowPatch::UpdateKeepOnTop {
                            id: meta_window.id.clone(),
                            value: keep_on_top,
                        },
                        true,
                    );
                }
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
                        self.patch_meta_window(
                            MetaWindowPatch::UpdateWindowClass {
                                id: meta_window.id,
                                value: (!class.is_empty()).then_some(class),
                            },
                            true,
                        );
                    }
                    WmWindowProperty::TransientFor => {
                        let transient_for = x11_surface.is_transient_for();
                        info!("transient_for changed: {:?}", transient_for);
                        // Turn a late transient relation into a parent so the
                        // window is routed as a dialog. Some apps only set it
                        // after the surface exists.
                        let parent_meta_window_id = transient_for.and_then(|parent_window| {
                            self.x11_surface_per_x11_window
                                .get(&parent_window)
                                .and_then(|parent_surface| parent_surface.wl_surface())
                                .and_then(|parent_wl_surface| {
                                    self.meta_window_state
                                        .meta_window_id_per_surface_id
                                        .get(&get_surface_id(&parent_wl_surface))
                                        .cloned()
                                })
                        });
                        if let Some(parent_meta_window_id) = parent_meta_window_id {
                            self.patch_meta_window(
                                MetaWindowPatch::UpdateParent {
                                    id: meta_window.id,
                                    value: Some(parent_meta_window_id),
                                },
                                true,
                            );
                        }
                    }
                    WmWindowProperty::MotifHints => {
                        let is_modal = crate::meta_window_state::x11_is_modal(&x11_surface);
                        info!("motif_hints changed: is_modal={is_modal}");
                        self.patch_meta_window(
                            MetaWindowPatch::UpdateIsModal {
                                id: meta_window.id,
                                value: is_modal,
                            },
                            true,
                        );
                    }
                    WmWindowProperty::NormalHints => {
                        let is_fixed_sized =
                            crate::meta_window_state::x11_is_fixed_sized(&x11_surface);
                        info!("normal_hints changed: is_fixed_sized={is_fixed_sized}");
                        self.patch_meta_window(
                            MetaWindowPatch::UpdateIsFixedSized {
                                id: meta_window.id,
                                value: is_fixed_sized,
                            },
                            true,
                        );
                    }
                    WmWindowProperty::StartupId => {
                        let startup_id = x11_surface.startup_id();
                        info!("startup_id changed: {:?}", startup_id);
                        self.patch_meta_window(
                            MetaWindowPatch::UpdateStartupId {
                                id: meta_window.id,
                                value: startup_id,
                            },
                            true,
                        );
                    }
                    WmWindowProperty::WindowType => {
                        info!("window_type changed: {:?}", x11_surface.window_type());
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
            let Some(wl_surface) = x11_surface.wl_surface() else {
                return;
            };
            let surface_id = get_surface_id(&wl_surface);
            let Some(meta_window) = self.get_meta_window(surface_id) else {
                return;
            };
            if !meta_window.allows_interactive_resize() {
                tracing::debug!(
                    target: "veshell::geometry",
                    meta_window_id = %meta_window.id,
                    display_mode = ?meta_window.display_mode,
                    "ignoring interactive_resize for tiled/maximized X11 window"
                );
                return;
            }
            let resize_edge = MetaResizeEdge::from(resize_edge);

            if meta_window.is_floating() {
                let pointer = self.pointer.current_location();
                self.start_floating_resize(meta_window.id.clone(), resize_edge, pointer);
                // Floating windows have exactly one resize path. Even when the
                // gesture is rejected (fixed size, missing placement), never
                // fall back to Flutter's local resize: that would desynchronise
                // the client surface from the compositor box.
                return;
            }
            let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
            platform_method_channel.invoke_method(
                "interactive_resize",
                Some(Box::new(json!({
                    "metaWindowId": meta_window.id,
                    "edge": resize_edge.bits()
                    ,
                }))),
                None,
            );
        }

        fn move_request(&mut self, _xwm: XwmId, x11_surface: X11Surface, _button: u32) {
            let Some(wl_surface) = x11_surface.wl_surface() else {
                return;
            };
            let surface_id = get_surface_id(&wl_surface);
            let Some(meta_window) = self.get_meta_window(surface_id) else {
                return;
            };

            // A floating X11 window is moved by the compositor: the client
            // asked the WM to do it (`_NET_WM_MOVERESIZE`), it does not move
            // itself. Tiled windows keep the previous notification-only path.
            if meta_window.is_floating() {
                let pointer = self.pointer.current_location();
                self.start_floating_move(meta_window.id.clone(), pointer);
                // A floating window has exactly one move path: the compositor
                // tracks the pointer and publishes the placement. Do not also
                // notify Flutter's local drag machinery.
                return;
            }

            let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
            platform_method_channel.invoke_method(
                "interactive_move",
                Some(Box::new(json!({
                        "metaWindowId": meta_window.id,
                }))),
                None,
            );
        }

        fn demands_attention_request(&mut self, _xwm: XwmId, x11_surface: X11Surface) {
            let Some(wl_surface) = x11_surface.wl_surface() else {
                return;
            };
            let surface_id = get_surface_id(&wl_surface);
            let Some(meta_window) = self.get_meta_window(surface_id) else {
                return;
            };
            let meta_window_id = meta_window.id;
            self.notify_window_attention_requested(&meta_window_id);
        }

        fn undemands_attention_request(&mut self, _xwm: XwmId, x11_surface: X11Surface) {
            let Some(wl_surface) = x11_surface.wl_surface() else {
                return;
            };
            let surface_id = get_surface_id(&wl_surface);
            let Some(meta_window) = self.get_meta_window(surface_id) else {
                return;
            };
            let meta_window_id = meta_window.id;
            self.notify_window_attention_released(&meta_window_id);
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
            let native_data = match selection {
                SelectionTarget::Clipboard => current_data_device_selection_userdata(&self.seat),
                SelectionTarget::Primary => current_primary_selection_userdata(&self.seat),
            };
            if let Some(data) = native_data.as_ref().and_then(|data| data.as_ref()) {
                if mime_type == PNG_MIME || mime_type == NATIVE_SCREENSHOT_MIME {
                    send_native_selection(fd, data.clone());
                    return;
                }
            }
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
                    set_data_device_selection(&self.display_handle, &self.seat, mime_types, None)
                }
                SelectionTarget::Primary => {
                    set_primary_selection(&self.display_handle, &self.seat, mime_types, None)
                }
            }
        }

        fn cleared_selection(&mut self, _xwm: XwmId, selection: SelectionTarget) {
            match selection {
                SelectionTarget::Clipboard => {
                    if current_data_device_selection_userdata(&self.seat)
                        .is_some_and(|data| data.is_none())
                    {
                        clear_data_device_selection(&self.display_handle, &self.seat)
                    }
                }
                SelectionTarget::Primary => {
                    if current_primary_selection_userdata(&self.seat)
                        .is_some_and(|data| data.is_none())
                    {
                        clear_primary_selection(&self.display_handle, &self.seat)
                    }
                }
            }
        }

        fn fullscreen_request(&mut self, _xwm: XwmId, window: X11Surface) {
            let geometry = window.geometry();
            let meta_window_id = window.wl_surface().and_then(|wl_surface| {
                self.get_meta_window(get_surface_id(&wl_surface))
                    .map(|meta_window| meta_window.id)
            });

            info!("is_fullscreen {:?}", window.is_fullscreen());
            window.set_fullscreen(true).unwrap();
            window.configure(geometry).unwrap();

            if let Some(id) = meta_window_id {
                self.patch_meta_window(
                    MetaWindowPatch::UpdateIsFullscreen { id, value: true },
                    true,
                );
            }
        }
        fn unfullscreen_request(&mut self, _xwm: XwmId, window: X11Surface) {
            let meta_window_id = window.wl_surface().and_then(|wl_surface| {
                self.get_meta_window(get_surface_id(&wl_surface))
                    .map(|meta_window| meta_window.id)
            });

            info!("unfullscreen_request");
            window.set_fullscreen(false).unwrap();

            if let Some(id) = meta_window_id {
                self.patch_meta_window(
                    MetaWindowPatch::UpdateIsFullscreen { id, value: false },
                    true,
                );
            }
        }
        fn maximize_request(&mut self, _xwm: XwmId, window: X11Surface) {
            info!("maximize_request");
            let meta_window = window
                .wl_surface()
                .and_then(|surface| self.get_meta_window(get_surface_id(&surface)));
            let Some(meta_window) = meta_window else {
                window.set_maximized(true).unwrap();
                return;
            };
            // Floating is the free-placement escape hatch: reject a client
            // maximize request there. A tiled window keeps the previous
            // behaviour: the shell already sizes the tile.
            if meta_window.is_floating() {
                let _ = window.set_maximized(false);
                self.patch_meta_window(
                    MetaWindowPatch::UpdateClientMaximized {
                        id: meta_window.id,
                        value: false,
                    },
                    true,
                );
            } else {
                window.set_maximized(true).unwrap();
            }
        }
        fn unmaximize_request(&mut self, _xwm: XwmId, window: X11Surface) {
            info!("unmaximize_request");
            let meta_window = window
                .wl_surface()
                .and_then(|surface| self.get_meta_window(get_surface_id(&surface)));
            let Some(meta_window) = meta_window else {
                window.set_maximized(false).unwrap();
                return;
            };
            if meta_window.is_floating() {
                let _ = window.set_maximized(false);
                self.patch_meta_window(
                    MetaWindowPatch::UpdateClientMaximized {
                        id: meta_window.id,
                        value: false,
                    },
                    true,
                );
            } else {
                window.set_maximized(false).unwrap();
            }
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
                "Associating X11 surface {:?} with wl_surface {:?} transient_for {:?}",
                x11_surface_id,
                wl_surface,
                surface.is_transient_for()
            );
            let parent_surface = surface
                .is_transient_for()
                .and_then(|parent_window| self.x11_surface_per_x11_window.get(&parent_window));

            let mapped_id = surface.mapped_window_id();
            info!("mapped_id: {:?}", mapped_id);
            let hints = surface.hints();
            info!("hints: {:?}", hints);
            let xwayland_scale_ratio = self
                .xwayland_state
                .as_ref()
                .unwrap()
                .client
                .get_data::<XWaylandClientData>()
                .unwrap()
                .compositor_state
                .client_scale();
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
                    let geometry = surface.geometry();
                    // X11 reports override-redirect popups at the root. Store
                    // them relative to the owning tile's content origin so the
                    // tile popup host can render them in every display mode.
                    // Subtract the parent's native root first: tiled X11
                    // parents are kept at root (0,0), not at their rendered
                    // tile origin.
                    let position = self
                        .meta_window_state
                        .x11_popup_tile_position(
                            parent_meta_window_id,
                            surface.last_configure().loc,
                        )
                        .unwrap_or_else(|| {
                            let tile_origin = self
                                .meta_window_state
                                .tile_content_origin(parent_meta_window_id)
                                .unwrap_or_else(|| Point::from((0, 0)));
                            surface.last_configure().loc - tile_origin
                        });
                    let meta_popup = self.create_meta_popup(MetaPopup {
                        id: Uuid::new_v4().hyphenated().to_string(),
                        category: x11_popup_category(&surface, geometry),
                        position: position.into(),
                        native_root: Some(surface.last_configure().loc.into()),
                        parent_relative: None,
                        parent: parent_meta_window_id.clone(),
                        surface_id: get_surface_id(wl_surface.borrow()),
                        scale_ratio: xwayland_scale_ratio,
                        geometry: Some(geometry.into()),
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
                    xwayland_scale_ratio,
                );
                self.meta_window_state
                    .meta_window_id_per_surface_id
                    .insert(get_surface_id(wl_surface.borrow()), meta_window.id);
            }
        }
    }
}
