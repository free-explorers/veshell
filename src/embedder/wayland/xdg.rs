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
        utils::{Logical, Rectangle, Serial, Size},
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
        flutter_engine::wayland_messages::{MyPoint, MyRectangle},
        meta_window_state::{
            meta_popup::{self, MetaPopup, MetaPopupCategory, MetaPopupPatch},
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

            // A client may create its `wp_fractional_scale` object before the
            // toplevel, so `new_fractional_scale` ran before this meta window
            // existed and set nothing. Seed the preferred scale now (smithay
            // stores it until the object exists) so the client renders on the
            // first buffer at the fallback scale even if no later patch changes
            // the value. `set_preferred_scale` is idempotent.
            with_states(surface.wl_surface(), |data| {
                with_fractional_scale(data, |fractional| {
                    fractional.set_preferred_scale(meta_window.scale_ratio);
                });
            });

            compositor::add_post_commit_hook(
                surface.wl_surface(),
                |state: &mut Self, _, surface| {
                    let surface_id = get_surface_id(surface);
                    let geometry: Option<MyRectangle<i32, Logical>> =
                        with_states(surface, |surface_data| {
                            surface_data
                                .cached_state
                                .get::<SurfaceCachedState>()
                                .current()
                                .geometry
                                .map(|geometry| geometry.into())
                        })
                        .or_else(|| {
                            // xdg-shell geometry is optional. Some clients
                            // (notably Blender) never call
                            // `wl_surface.set_window_geometry`, so the
                            // committed buffer is the only size information
                            // available. Without this fallback the window has
                            // no placement and cannot be moved or resized.
                            let (_, buffer_size) = state
                                .texture_ids_per_surface_id
                                .get(&surface_id)?
                                .last()?
                                .clone();
                            let scale = state
                                .get_meta_window(surface_id)
                                .map(|meta_window| meta_window.scale_ratio)
                                .unwrap_or(1.0)
                                .max(1.0);
                            let width = (f64::from(buffer_size.w) / scale).round() as i32;
                            let height = (f64::from(buffer_size.h) / scale).round() as i32;
                            (width > 0 && height > 0)
                                .then(|| Rectangle::from_size(Size::from((width, height))).into())
                        });
                    info!(
                        target: "veshell::geometry",
                        surface_id,
                        geometry = ?geometry,
                        "XDG toplevel geometry after commit"
                    );
                    if let Some(meta_window_id) = state
                        .meta_window_state
                        .meta_window_id_per_surface_id
                        .get(&surface_id)
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
            let position = self
                .meta_window_state
                .popup_tile_position(&parent_meta_window_id, position)
                .unwrap_or(position);

            info!(
                target: "veshell::geometry",
                surface_id,
                parent_surface_id,
                parent_meta_window_id = %parent_meta_window_id,
                position = ?position,
                geometry = ?geometry,
                "Creating popup with parent-box-relative position"
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
                category: MetaPopupCategory::Popup,
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
            let Some(meta_window) = self.get_meta_window(surface_id) else {
                return;
            };
            // A floating Wayland toplevel has no native position to configure;
            // the compositor tracks the move and publishes the new box origin.
            // Tiled windows keep the legacy notification-only path.
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

        fn resize_request(
            &mut self,
            surface: ToplevelSurface,
            _seat: WlSeat,
            serial: Serial,
            edges: xdg_toplevel::ResizeEdge,
        ) {
            let surface_id = get_surface_id(surface.wl_surface());
            let Some(meta_window) = self.get_meta_window(surface_id) else {
                return;
            };

            let Some(pointer) = self.seat.get_pointer() else {
                return;
            };
            if pointer.has_grab(serial) {
                pointer.unset_grab(self, serial, self.clock.now().as_millis() as u32);
            }

            if !meta_window.allows_interactive_resize() {
                tracing::debug!(
                    target: "veshell::geometry",
                    meta_window_id = %meta_window.id,
                    display_mode = ?meta_window.display_mode,
                    "ignoring interactive_resize for tiled/maximized window"
                );
                return;
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

            let resize_edge = MetaResizeEdge::from(edges);
            info!("resize_request Resize edge: {:?}", resize_edge);
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
                // Read the location under the popup lock, but compute the
                // toplevel-relative position after releasing it:
                // `get_popup_toplevel_coords` re-locks the popup's own
                // `XdgPopupSurfaceData` through `parent()`, which deadlocks if
                // nested inside `with_pending_state`.
                let geometry_loc = surface.with_pending_state(|state| state.geometry.loc);
                let parent_relative =
                    geometry_loc + get_popup_toplevel_coords(&PopupKind::Xdg(surface.clone()));
                let parent_meta_window_id = self
                    .meta_window_state
                    .meta_popups
                    .get(&meta_popup_id)
                    .map(|popup| popup.parent.clone());
                let position = parent_meta_window_id
                    .as_deref()
                    .and_then(|parent| {
                        self.meta_window_state
                            .popup_tile_position(parent, parent_relative)
                    })
                    .unwrap_or(parent_relative);
                self.patch_meta_popup(
                    MetaPopupPatch::UpdatePosition {
                        id: meta_popup_id,
                        value: position.into(),
                    },
                    true,
                );
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

        fn maximize_request(&mut self, surface: ToplevelSurface) {
            let Some(meta_window) = self.get_meta_window(get_surface_id(surface.wl_surface()))
            else {
                surface.send_configure();
                return;
            };
            // Floating is the free-placement escape hatch: a client maximize
            // request is not honored there, because the shell has no
            // maximize/unmaximize affordance to get out of it. Tiled windows
            // keep the toplevel negotiation driven by their display mode.
            if meta_window.is_floating() {
                surface.with_pending_state(|state| {
                    state.states.unset(xdg_toplevel::State::Maximized);
                });
                surface.send_configure();
                self.patch_meta_window(
                    MetaWindowPatch::UpdateClientMaximized {
                        id: meta_window.id,
                        value: false,
                    },
                    true,
                );
            } else {
                surface.send_configure();
            }
        }

        fn unmaximize_request(&mut self, surface: ToplevelSurface) {
            let Some(meta_window) = self.get_meta_window(get_surface_id(surface.wl_surface()))
            else {
                return;
            };
            if meta_window.is_floating() {
                self.patch_meta_window(
                    MetaWindowPatch::UpdateClientMaximized {
                        id: meta_window.id,
                        value: false,
                    },
                    true,
                );
            }
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
                let is_maximized = configure
                    .state
                    .states
                    .contains(xdg_toplevel::State::Maximized);

                if let Some(meta_window) = self.get_meta_window(get_surface_id(&surface)) {
                    self.patch_meta_window(
                        MetaWindowPatch::UpdateNeedDecoration {
                            id: meta_window.id.clone(),
                            value: is_ssd,
                        },
                        true,
                    );
                    // Floating is always unmaximized. A stale maximized
                    // configure ack must not re-enable the flag after the
                    // display mode has switched to floating.
                    self.patch_meta_window(
                        MetaWindowPatch::UpdateClientMaximized {
                            id: meta_window.id.clone(),
                            value: is_maximized && !meta_window.is_floating(),
                        },
                        true,
                    );
                    // The acked configure is the state the toplevel actually
                    // negotiated: patch the fullscreen hint from it so a client
                    // request and a later shell-driven un-fullscreen both clear
                    // or set it (the `fullscreen_request` handler alone would
                    // latch it).
                    self.patch_meta_window(
                        MetaWindowPatch::UpdateIsFullscreen {
                            id: meta_window.id,
                            value: configure
                                .state
                                .states
                                .contains(xdg_toplevel::State::Fullscreen),
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
            token: XdgActivationToken,
            token_data: XdgActivationTokenData,
            surface: WlSurface,
        ) {
            // A token minted by the notification server for an invoked action
            // is trusted: the user asked for the window, so honor the
            // activation by focusing it instead of reading it as a demand for
            // attention.
            if let Some(meta_window_id) = self.take_notification_activation_token(token.as_str()) {
                self.xdg_activation_state.remove_token(&token);
                match crate::flutter_engine::platform_channel_callbacks::activate_window::focus_surface(
                    self,
                    &surface,
                ) {
                    Ok(()) => {
                        info!(
                            target: "veshell::geometry",
                            meta_window_id,
                            "xdg_activation: notification token focused its window"
                        );
                        // The compositor focused the surface, but only the
                        // shell can select the workspace/tile that makes the
                        // window visible.
                        self.notify_window_activation_requested(&meta_window_id);
                    }
                    Err((code, message)) => warn!(
                        target: "veshell::geometry",
                        error = code,
                        message,
                        "xdg_activation: notification token could not focus its window"
                    ),
                }
                return;
            }

            let activated_surface_id = get_surface_id(&surface);

            // Only the opener the requesting client actually declared. The
            // previous fallback to the keyboard-focused surface made
            // `activatedBy` mean "whatever was focused" for programmatic
            // windows (e.g. a browser restoring its session), so the shell
            // attached them as dialogs of an unrelated tile. A token with no
            // declared opener now records no relation and the window is matched
            // normally. If that turns out to drop useful same-application
            // hints, scope a fallback to the focused surface of the *same*
            // application instead of using it unconditionally (see
            // docs/specifications/matching_algorithm.md, "Dialog routing").
            let requesting_surface = token_data.surface.clone();

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
                        id: activated_meta_window_id.clone(),
                        value: Some(requesting_meta_window_id),
                    },
                    true,
                );
                // Activating a window that already exists is an attention
                // request: surface it as a notification instead of focusing
                // the window behind the user's back.
                self.notify_window_attention_requested(&activated_meta_window_id);
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

        /// Re-constrain every popup owned by `meta_window_id` against the
        /// window's current geometry and push the updated positions to Flutter.
        ///
        /// A popup's geometry is only computed when it is created or the client
        /// repositions it. A tiled window is resized by the shell, so an open
        /// popup would otherwise keep a position derived from the previous
        /// toplevel size and end up outside the new tile.
        pub(crate) fn reconstrain_popups_for_root(&mut self, meta_window_id: &str) {
            let popups: Vec<(String, PopupSurface)> = self
                .meta_window_state
                .meta_popups
                .values()
                .filter(|popup| popup.parent.as_str() == meta_window_id)
                .filter_map(|popup| {
                    self.xdg_popups
                        .get(&popup.surface_id)
                        .cloned()
                        .map(|surface| (popup.id.clone(), surface))
                })
                .collect();

            for (meta_popup_id, surface) in popups {
                let previous_position = self
                    .meta_window_state
                    .meta_popups
                    .get(&meta_popup_id)
                    .map(|popup| popup.position.0);
                self.constrain_popup_to_parent(&PopupKind::Xdg(surface.clone()));
                // `get_popup_toplevel_coords` re-locks the popup's own
                // `XdgPopupSurfaceData` via `parent()`, so it must run after
                // `with_pending_state` has released the lock.
                let geometry_loc = surface.with_pending_state(|state| state.geometry.loc);
                let parent_relative =
                    geometry_loc + get_popup_toplevel_coords(&PopupKind::Xdg(surface.clone()));
                let new_position = self
                    .meta_window_state
                    .popup_tile_position(meta_window_id, parent_relative)
                    .unwrap_or(parent_relative);
                if previous_position == Some(new_position) {
                    continue;
                }
                info!(
                    target: "veshell::geometry",
                    popup_id = %meta_popup_id,
                    old_position = ?previous_position,
                    new_position = ?new_position,
                    "Re-constraining popup after root resize"
                );
                self.patch_meta_popup(
                    MetaPopupPatch::UpdatePosition {
                        id: meta_popup_id,
                        value: new_position.into(),
                    },
                    true,
                );
            }
        }
    }
}
