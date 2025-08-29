pub mod xdg {
    use std::cell::RefCell;

    use serde_json::json;
    use smithay::{
        backend::renderer::utils::with_renderer_surface_state,
        desktop::{find_popup_root_surface, get_popup_toplevel_coords, PopupKind},
        reexports::{
            wayland_protocols::xdg::{
                decoration::zv1::server::zxdg_toplevel_decoration_v1, shell::server::xdg_toplevel,
            },
            wayland_server::{
                protocol::{wl_seat::WlSeat, wl_surface::WlSurface},
                Resource,
            },
        },
        utils::{Logical, Rectangle, Serial},
        wayland::{
            compositor::{self, add_post_commit_hook, with_states},
            fractional_scale::with_fractional_scale,
            shell::xdg::{
                decoration::XdgDecorationHandler, Configure, PopupSurface, PositionerState,
                SurfaceCachedState, ToplevelSurface, XdgPopupSurfaceData, XdgShellHandler,
                XdgShellState, XdgToplevelSurfaceData,
            },
        },
    };
    use tracing::{info, warn};
    use uuid::Uuid;

    use crate::{
        flutter_engine::wayland_messages::MyPoint,
        meta_window_state::{
            meta_popup::{self, MetaPopup, MetaPopupPatch},
            meta_resize_edge::MetaResizeEdge,
            meta_window::{self, MetaWindowPatch},
        },
        state::State,
        wayland::wayland::{get_surface_id, WlSurfaceVeshellState},
        Backend,
    };

    impl<BackendData: Backend> XdgShellHandler for State<BackendData> {
        fn xdg_shell_state(&mut self) -> &mut XdgShellState {
            &mut self.xdg_shell_state
        }

        fn new_toplevel(&mut self, surface: ToplevelSurface) {
            info!("new_toplevel {:?}", surface);
            let surface_id = get_surface_id(surface.wl_surface());
            self.xdg_toplevels.insert(surface_id, surface.clone());

            surface.with_pending_state(|state| {
                state.states.set(xdg_toplevel::State::Activated);
            });

            let meta_window = self.new_meta_window_for_toplevel(surface.clone());
            self.meta_window_state
                .meta_window_id_per_surface_id
                .insert(surface_id, meta_window.id.clone());

            compositor::add_post_commit_hook(
                surface.wl_surface(),
                |state: &mut Self, _, surface| {
                    let geometry = with_states(surface, |surface_data| {
                        surface_data
                            .cached_state
                            .get::<SurfaceCachedState>()
                            .current()
                            .geometry
                            .map(|geometry| geometry.into())
                    });
                    if let Some(meta_window_id) = state
                        .meta_window_state
                        .meta_window_id_per_surface_id
                        .get(&get_surface_id(surface))
                    {
                        state.patch_meta_window(
                            MetaWindowPatch::UpdateGeometry {
                                id: meta_window_id.clone(),
                                value: geometry,
                            },
                            true,
                        );
                    }
                },
            );
        }

        fn new_popup(&mut self, surface: PopupSurface, positioner: PositionerState) {
            self.constrain_popup_to_parent(&PopupKind::Xdg(surface.clone()));

            let (surface_id, parent) = with_states(surface.wl_surface(), |surface_data| {
                let surface_id = surface_data
                    .data_map
                    .get::<RefCell<WlSurfaceVeshellState>>()
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
            let mut position: smithay::utils::Point<i32, Logical> =
                surface.with_pending_state(|state| state.geometry.loc);

            let geometry = with_states(surface.wl_surface(), |surface_data| {
                surface_data
                    .cached_state
                    .get::<SurfaceCachedState>()
                    .current()
                    .geometry
                    .map(|geometry| geometry.into())
            });
            // TODO: Revise this unwrap.
            // Wayland states that popups without parents can exist but I don't know in what case.
            let parent_surface_id = get_surface_id(&parent.unwrap());

            // Parent id can be either meta window or meta popup.
            let parent_meta_window_id = self
                .meta_window_state
                .meta_window_id_per_surface_id
                .get(&parent_surface_id)
                .cloned()
                .unwrap_or_else(|| {
                    let parent_meta_popup = self.get_meta_popup(parent_surface_id).unwrap();
                    position = (
                        position.x + parent_meta_popup.position.0.x,
                        position.y + parent_meta_popup.position.0.y,
                    )
                        .into();
                    // if parent is a meta popup find the root meta window
                    let mut meta_parent_id = parent_meta_popup.parent;
                    while !self
                        .meta_window_state
                        .meta_windows
                        .contains_key(&meta_parent_id)
                    {
                        let parent_meta_popup = self
                            .meta_window_state
                            .meta_popups
                            .get(&meta_parent_id)
                            .unwrap();
                        position = (
                            position.x + parent_meta_popup.position.0.x,
                            position.y + parent_meta_popup.position.0.y,
                        )
                            .into();
                        meta_parent_id = parent_meta_popup.parent.clone();
                    }
                    meta_parent_id.clone()
                });

            /* let root_parent = find_popup_root_surface(&PopupKind::Xdg(surface.clone())).unwrap();
            let parent_surface_id = get_surface_id(&root_parent);
            let parent_meta_window_id = self
                .meta_window_state
                .meta_window_id_per_surface_id
                .get(&parent_surface_id)
                .cloned()
                .unwrap();

            let position = get_popup_toplevel_coords(&PopupKind::Xdg(surface.clone())); */

            let scale_ratio = {
                self.meta_window_state
                    .meta_windows
                    .get_mut(&parent_meta_window_id)
                    .unwrap()
                    .scale_ratio
            };

            let meta_popup = self.create_meta_popup(MetaPopup {
                id: Uuid::new_v4().hyphenated().to_string(),
                parent: parent_meta_window_id,
                position: position.into(),
                surface_id,
                scale_ratio: scale_ratio,
                geometry: geometry,
            });
            self.meta_window_state
                .meta_popup_id_per_surface_id
                .insert(surface_id, meta_popup.id.clone());

            compositor::add_post_commit_hook(
                surface.wl_surface(),
                |state: &mut Self, _, surface| {
                    let geometry = with_states(surface, |surface_data| {
                        surface_data
                            .cached_state
                            .get::<SurfaceCachedState>()
                            .current()
                            .geometry
                            .map(|geometry| geometry.into())
                    });
                    if let Some(meta_popup_id) = state
                        .meta_window_state
                        .meta_popup_id_per_surface_id
                        .get(&get_surface_id(surface))
                    {
                        state.patch_meta_popup(
                            MetaPopupPatch::UpdateGeometry {
                                id: meta_popup_id.clone(),
                                value: geometry,
                            },
                            true,
                        );
                    }
                },
            );
        }

        fn move_request(&mut self, surface: ToplevelSurface, _seat: WlSeat, _serial: Serial) {
            let surface_id = get_surface_id(surface.wl_surface());
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

        fn resize_request(
            &mut self,
            surface: ToplevelSurface,
            _seat: WlSeat,
            serial: Serial,
            edges: xdg_toplevel::ResizeEdge,
        ) {
            let surface_id = get_surface_id(surface.wl_surface());
            let meta_window = self.get_meta_window(surface_id).unwrap();

            let pointer = self.seat.get_pointer().unwrap();
            if pointer.has_grab(serial) {
                pointer.unset_grab(self, serial, self.clock.now().as_millis() as u32);
            }

            // See if this comes from a touch grab.
            /*             if let Some(touch) = self.niri.seat.get_touch() {
                if touch.has_grab(serial) {
                    if let Some(start_data) = touch.grab_start_data() {
                        if let Some((focus, _)) = &start_data.focus {
                            if focus.id().same_client_as(&wl_surface.id()) {
                                grab_start_data = Some(PointerOrTouchStartData::Touch(start_data));
                            }
                        }
                    }
                }
            } */

            let platform_method_channel = &mut self.flutter_engine_mut().platform_method_channel;
            let resize_edge = MetaResizeEdge::from(edges);
            info!("resize_request Resize edge: {:?}", resize_edge);
            platform_method_channel.invoke_method(
                "interactive_resize",
                Some(Box::new(json!({
                    "metaWindowId": meta_window.id,
                    "edge": resize_edge.bits(),
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
            positioner: PositionerState,
            token: u32,
        ) {
            surface.with_pending_state(|state| {
                let geometry = positioner.get_geometry();
                state.geometry = geometry;
                state.positioner = positioner;
            });
            self.constrain_popup_to_parent(&PopupKind::Xdg(surface.clone()));

            if let Some(meta_popup_id) = self
                .meta_window_state
                .meta_popup_id_per_surface_id
                .get(&get_surface_id(surface.wl_surface()))
                .cloned()
            {
                surface.with_pending_state(|state| {
                    self.patch_meta_popup(
                        MetaPopupPatch::UpdatePosition {
                            id: meta_popup_id,
                            value: state.geometry.loc.into(),
                        },
                        true,
                    );
                });
            }
            surface.send_repositioned(token);
            if let Err(err) = surface.send_configure() {
                warn!(
                    ?err,
                    "Client bug: Unable to re-configure repositioned popup.",
                );
            }
        }

        fn toplevel_destroyed(&mut self, surface: ToplevelSurface) {
            let surface_id = get_surface_id(surface.wl_surface());
            self.xdg_toplevels.remove(&surface_id);

            if let Some(meta_window_id) = self
                .meta_window_state
                .meta_window_id_per_surface_id
                .remove(&surface_id)
            {
                self.remove_meta_window(&meta_window_id);
            }
        }

        fn popup_destroyed(&mut self, surface: PopupSurface) {
            let surface_id = get_surface_id(surface.wl_surface());
            self.xdg_popups.remove(&surface_id);

            if let Some(meta_popup_id) = self
                .meta_window_state
                .meta_popup_id_per_surface_id
                .remove(&surface_id)
            {
                self.remove_meta_popup(&meta_popup_id);
            }
        }

        fn app_id_changed(&mut self, surface: ToplevelSurface) {
            let surface_id = get_surface_id(surface.wl_surface());

            let app_id = with_states(surface.wl_surface(), |surface_data| {
                surface_data
                    .data_map
                    .get::<XdgToplevelSurfaceData>()
                    .unwrap()
                    .lock()
                    .unwrap()
                    .app_id
                    .clone()
            });

            if let Some(meta_window) = self.get_meta_window(surface_id) {
                self.patch_meta_window(
                    MetaWindowPatch::UpdateAppId {
                        id: meta_window.id,
                        value: app_id.clone(),
                    },
                    true,
                );
            }
        }

        fn title_changed(&mut self, surface: ToplevelSurface) {
            let surface_id = get_surface_id(surface.wl_surface());

            let title = with_states(surface.wl_surface(), |surface_data| {
                surface_data
                    .data_map
                    .get::<XdgToplevelSurfaceData>()
                    .unwrap()
                    .lock()
                    .unwrap()
                    .title
                    .clone()
            });
            if let Some(meta_window) = self.get_meta_window(surface_id) {
                self.patch_meta_window(
                    MetaWindowPatch::UpdateTitle {
                        id: meta_window.id,
                        value: title.clone(),
                    },
                    true,
                );
            }
        }

        fn fullscreen_request(
            &mut self,
            surface: ToplevelSurface,
            _output: Option<smithay::reexports::wayland_server::protocol::wl_output::WlOutput>,
        ) {
            surface.with_pending_state(|state| {
                state.states.set(xdg_toplevel::State::Fullscreen);
            });
            surface.send_configure();
        }

        fn unfullscreen_request(&mut self, surface: ToplevelSurface) {
            surface.with_pending_state(|state| {
                state.states.unset(xdg_toplevel::State::Fullscreen);
            });
            surface.send_configure();
        }

        fn ack_configure(
            &mut self,
            surface: smithay::reexports::wayland_server::protocol::wl_surface::WlSurface,
            configure: smithay::wayland::shell::xdg::Configure,
        ) {
            if let Configure::Toplevel(configure) = configure {
                let is_ssd = configure
                    .state
                    .decoration_mode
                    .map(|mode| mode == zxdg_toplevel_decoration_v1::Mode::ServerSide)
                    .unwrap_or(false);

                if let Some(meta_window) = self.get_meta_window(get_surface_id(&surface)) {
                    self.patch_meta_window(
                        MetaWindowPatch::UpdateNeedDecoration {
                            id: meta_window.id,
                            value: is_ssd,
                        },
                        true,
                    );
                }
            }
        }
        fn parent_changed(&mut self, surface: ToplevelSurface) {
            info!("parent changed");
            if let Some(meta_window) = self.get_meta_window(get_surface_id(surface.wl_surface())) {
                self.patch_meta_window(
                    MetaWindowPatch::UpdateParent {
                        id: meta_window.id,
                        value: surface.parent().and_then(|parent| {
                            self.get_meta_window(get_surface_id(&parent))
                                .map(|mw| mw.id.clone())
                        }),
                    },
                    true,
                );
            }
        }
    }

    impl<BackendData: Backend> XdgDecorationHandler for State<BackendData> {
        fn new_decoration(&mut self, toplevel: ToplevelSurface) {
            // If we want CSD, we hide this global altogether.
            toplevel.with_pending_state(|state| {
                state.decoration_mode = Some(zxdg_toplevel_decoration_v1::Mode::ServerSide);
            });
        }

        fn request_mode(
            &mut self,
            toplevel: ToplevelSurface,
            mode: zxdg_toplevel_decoration_v1::Mode,
        ) {
            // Set whatever the client wants, rather than our preferred mode. This especially matters
            // for SDL2 which has a bug where forcing a different (client-side) decoration mode during
            // their window creation sequence would leave the window permanently hidden.
            //
            // https://github.com/libsdl-org/SDL/issues/8173
            //
            // The bug has been fixed, but there's a ton of apps which will use the buggy version for a
            // long while...
            toplevel.with_pending_state(|state| state.decoration_mode = Some(mode));

            if toplevel.is_initial_configure_sent() {
                toplevel.send_pending_configure();
            }
        }

        fn unset_mode(&mut self, toplevel: ToplevelSurface) {
            // If we want CSD, we hide this global altogether.
            toplevel.with_pending_state(|state| {
                state.decoration_mode = Some(zxdg_toplevel_decoration_v1::Mode::ClientSide);
            });

            // A configure is required in response to this event. However, if an initial configure
            // wasn't sent, then we will send this as part of the initial configure later.
            if toplevel.is_initial_configure_sent() {
                toplevel.send_configure();
            }
        }
    }

    impl<BackendData: Backend> State<BackendData> {
        fn constrain_popup_to_parent(&mut self, popup: &PopupKind) {
            let Ok(root) = find_popup_root_surface(popup) else {
                return;
            };
            if let PopupKind::Xdg(popup) = popup {
                let toplevel = self.xdg_toplevels.get(&get_surface_id(&root)).unwrap();
                let target: Rectangle<i32, Logical> = toplevel.with_pending_state(|state| {
                    let size = state.size.or(Some((0, 0).into())).unwrap();
                    Rectangle::new((0, 0).into(), (size.w, size.h).into())
                });

                popup.with_pending_state(|state| {
                    state.geometry = state.positioner.get_unconstrained_geometry(target)
                });
            }
        }
    }
}
