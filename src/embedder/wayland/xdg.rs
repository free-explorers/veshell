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
                decoration::XdgDecorationHandler,
                dialog::{ToplevelDialogHint, XdgDialogHandler},
                Configure, PopupSurface, PositionerState, SurfaceCachedState, ToplevelSurface,
                XdgPopupSurfaceData, XdgShellHandler, XdgShellState, XdgToplevelSurfaceData,
            },
            xdg_activation::{
                XdgActivationHandler, XdgActivationState, XdgActivationToken,
                XdgActivationTokenData,
            },
        },
    };
    use tracing::{info, warn};
    use uuid::Uuid;

    use crate::{
        flutter_engine::wayland_messages::MyPoint,
        focus::KeyboardFocusTarget,
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
                    info!(
                        target: "veshell::geometry",
                        surface_id = get_surface_id(surface),
                        geometry = ?geometry,
                        "XDG toplevel geometry after commit"
                    );
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
            surface.with_pending_state(|state| {
                state.geometry = positioner.get_geometry();
                state.positioner = positioner;
            });
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
            let position = surface.with_pending_state(|state| state.geometry.loc)
                + get_popup_toplevel_coords(&PopupKind::Xdg(surface.clone()));

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

            // Parent id can be either the root meta window or a meta popup.
            let parent_meta_window_id = self
                .meta_window_state
                .meta_window_id_per_surface_id
                .get(&parent_surface_id)
                .cloned()
                .or_else(|| {
                    self.get_meta_popup(parent_surface_id)
                        .map(|popup| popup.parent)
                })
                .expect("Popup parent has no root meta window");

            info!(
                target: "veshell::geometry",
                surface_id,
                parent_surface_id,
                parent_meta_window_id = %parent_meta_window_id,
                position = ?position,
                geometry = ?geometry,
                "Creating popup with root-relative position"
            );

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
                    info!(
                        target: "veshell::geometry",
                        surface_id = get_surface_id(surface),
                        geometry = ?geometry,
                        "XDG popup geometry after commit"
                    );
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
                    let position = state.geometry.loc
                        + get_popup_toplevel_coords(&PopupKind::Xdg(surface.clone()));
                    self.patch_meta_popup(
                        MetaPopupPatch::UpdatePosition {
                            id: meta_popup_id,
                            value: position.into(),
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

    /// Advertises `xdg_dialog_v1` so toolkits can mark modal/dialog toplevels.
    /// The hint is also read from the toplevel state on each commit (see the
    /// mapped-state update in `wayland::commit`); patching it here makes the
    /// change visible immediately.
    impl<BackendData: Backend> XdgDialogHandler for State<BackendData> {
        fn dialog_hint_changed(&mut self, toplevel: ToplevelSurface, hint: ToplevelDialogHint) {
            let surface_id = get_surface_id(toplevel.wl_surface());
            let Some(meta_window_id) = self
                .meta_window_state
                .meta_window_id_per_surface_id
                .get(&surface_id)
                .cloned()
            else {
                return;
            };
            self.patch_meta_window(
                MetaWindowPatch::UpdateIsModal {
                    id: meta_window_id,
                    value: hint == ToplevelDialogHint::Modal,
                },
                true,
            );
        }
    }

    /// Advertises `xdg_activation_v1`. The activation token carries the
    /// surface that requested the activation (e.g. the main Code OSS window),
    /// which is a per-window "opened from" relation that toolkits such as
    /// Electron rely on instead of `xdg_toplevel.set_parent`. When known, it
    /// is turned into a transient parent so the existing dialog routing groups
    /// the new window under the correct application instance.
    impl<BackendData: Backend> XdgActivationHandler for State<BackendData> {
        fn activation_state(&mut self) -> &mut XdgActivationState {
            &mut self.xdg_activation_state
        }

        fn request_activation(
            &mut self,
            _token: XdgActivationToken,
            token_data: XdgActivationTokenData,
            surface: WlSurface,
        ) {
            let activated_surface_id = get_surface_id(&surface);

            let focused_surface = match self.keyboard.current_focus() {
                Some(KeyboardFocusTarget::WlSurface(focused)) => Some(focused),
                _ => None,
            };

            // Prefer the surface the requesting client declared; fall back to
            // the currently keyboard-focused surface, which for a freshly
            // opened child is the window the user acted on.
            let requesting_surface = token_data
                .surface
                .clone()
                .or_else(|| focused_surface.clone());

            let requesting_meta_window_id = requesting_surface.and_then(|requesting| {
                let requesting_surface_id = get_surface_id(&requesting);
                if requesting_surface_id == activated_surface_id {
                    return None;
                }
                self.meta_window_state
                    .meta_window_id_per_surface_id
                    .get(&requesting_surface_id)
                    .cloned()
            });

            let activated_meta_window_id = self
                .meta_window_state
                .meta_window_id_per_surface_id
                .get(&activated_surface_id)
                .cloned();

            let Some(requesting_meta_window_id) = requesting_meta_window_id else {
                info!(
                    target: "veshell::geometry",
                    activated_surface_id,
                    "xdg_activation: no requesting window to associate"
                );
                return;
            };

            if let Some(activated_meta_window_id) = activated_meta_window_id {
                // Record the activation relation independently of any
                // client-declared parent: it is only an owner hint, not a
                // dialog marker.
                info!(
                    target: "veshell::geometry",
                    activated_meta_window_id = %activated_meta_window_id,
                    requesting_meta_window_id = %requesting_meta_window_id,
                    "xdg_activation: assigning activation relation"
                );
                self.patch_meta_window(
                    MetaWindowPatch::UpdateActivatedBy {
                        id: activated_meta_window_id,
                        value: Some(requesting_meta_window_id),
                    },
                    true,
                );
            } else {
                // The activated surface has no meta window yet; remember the
                // relation so `new_meta_window_for_toplevel` applies it at
                // creation, before the window is mapped.
                self.meta_window_state
                    .pending_activation_parent
                    .insert(activated_surface_id, requesting_meta_window_id);
            }
        }
    }

    impl<BackendData: Backend> State<BackendData> {
        fn constrain_popup_to_parent(&mut self, popup: &PopupKind) {
            let Ok(root) = find_popup_root_surface(popup) else {
                return;
            };
            let PopupKind::Xdg(popup) = popup else {
                return;
            };
            let root_surface_id = get_surface_id(&root);
            let Some(toplevel) = self.xdg_toplevels.get(&root_surface_id) else {
                return;
            };
            let parent_offset = get_popup_toplevel_coords(&PopupKind::Xdg(popup.clone()));
            let size = self
                .get_meta_window(root_surface_id)
                .and_then(|window| window.geometry.map(|geometry| geometry.0.size))
                .or_else(|| toplevel.with_pending_state(|state| state.size))
                .unwrap_or((0, 0).into());
            let target = Rectangle::new(
                (-parent_offset.x, -parent_offset.y).into(),
                (size.w, size.h).into(),
            );

            info!(
                target: "veshell::geometry",
                root_surface_id,
                parent_offset = ?parent_offset,
                target = ?target,
                popup_size = ?popup.with_pending_state(|state| state.geometry.size),
                "Constraining popup to toplevel geometry"
            );

            popup.with_pending_state(|state| {
                state.geometry = state.positioner.get_unconstrained_geometry(target)
            });
        }
    }
}
