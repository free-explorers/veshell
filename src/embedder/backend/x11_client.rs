use std::sync::atomic::Ordering;

use log::{error, warn};
use smithay::backend::allocator::dmabuf::{AnyError, AsDmabuf, Dmabuf};
use smithay::backend::allocator::{Allocator, Fourcc, Slot, Swapchain};
use smithay::backend::input::{Event, InputEvent, KeyState, KeyboardKeyEvent};
use smithay::backend::renderer::damage::OutputDamageTracker;
use smithay::backend::renderer::element::surface::{
    render_elements_from_surface_tree, WaylandSurfaceRenderElement,
};
use smithay::backend::renderer::element::texture::TextureRenderElement;
use smithay::backend::renderer::element::Kind;
use smithay::backend::renderer::gles::ffi::Gles2;
use smithay::backend::renderer::gles::GlesRenderer;
use smithay::backend::renderer::{Bind, ImportDma, ImportEgl};
use smithay::backend::x11::X11Input;
use smithay::delegate_dmabuf;
use smithay::output::{Output, PhysicalProperties, Scale, Subpixel};
use smithay::reexports::ash::ext;
use smithay::reexports::calloop::channel::Event as CalloopEvent;
use smithay::reexports::calloop::channel::Event::Msg;
use smithay::reexports::gbm::Format;
use smithay::reexports::wayland_server::protocol::wl_shm;
use smithay::reexports::x11rb::protocol::xproto::{
    AutoRepeatMode, ChangeKeyboardControlAux, ConnectionExt,
};
use smithay::wayland::dmabuf::{
    DmabufFeedbackBuilder, DmabufGlobal, DmabufHandler, DmabufState, ImportNotifier,
};
use smithay::{
    backend::{
        allocator::{
            dmabuf::DmabufAllocator,
            gbm::GbmAllocator,
            vulkan::{ImageUsageFlags, VulkanAllocator},
        },
        egl::{self},
        vulkan::{self, version::Version},
        x11::{self, X11Event, X11Surface},
    },
    output::Mode,
    reexports::{
        calloop::EventLoop,
        gbm::{self, BufferObjectFlags as GbmBufferFlags},
        wayland_server::Display,
    },
    utils::DeviceFd,
};
use tracing::{debug, info};

use crate::flutter_engine::embedder::FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse;
use crate::flutter_engine::FlutterEngine;
use crate::keyboard::{self, handle_keyboard_event};
use crate::{flutter_engine::EmbedderChannels, send_frames_surface_tree, State};
use crate::{settings, state};

use super::render::{get_render_elements, get_surface_elements, VeshellRenderElements};
use super::Backend;

impl DmabufHandler for State<X11Data> {
    fn dmabuf_state(&mut self) -> &mut DmabufState {
        self.dmabuf_state.as_mut().unwrap()
    }

    fn dmabuf_imported(
        &mut self,
        _global: &DmabufGlobal,
        dmabuf: Dmabuf,
        notifier: ImportNotifier,
    ) {
        if self
            .backend_data
            .renderer
            .import_dmabuf(&dmabuf, None)
            .is_ok()
        {
            let _ = notifier.successful::<State<X11Data>>();
        } else {
            notifier.failed();
        }
    }
}
delegate_dmabuf!(State<X11Data>);

pub fn run_x11_client() {
    let mut event_loop = EventLoop::try_new().unwrap();
    let display: Display<State<X11Data>> = Display::new().unwrap();
    let mut display_handle = display.handle();

    let x11_backend = x11::X11Backend::new().expect("Failed to initilize X11 backend");
    let x11_handle = x11_backend.handle();

    // Don't let X.Org send us repeated down and up events when a key is held down.
    // Wayland clients are expected to handle key repeats by themselves.
    x11_handle
        .connection()
        .change_keyboard_control(
            &ChangeKeyboardControlAux::new().auto_repeat_mode(AutoRepeatMode::OFF),
        )
        .unwrap();

    let (node, fd) = x11_handle
        .drm_node()
        .expect("Could not get DRM node used by X server");

    let gbm_device = gbm::Device::new(DeviceFd::from(fd)).expect("Failed to create gbm device");
    let egl_display =
        unsafe { egl::EGLDisplay::new(gbm_device.clone()) }.expect("Failed to create EGLDisplay");
    let egl_context = egl::EGLContext::new(&egl_display).expect("Failed to create EGLContext");

    let window = x11::WindowBuilder::new()
        .title("Veshell")
        .build(&x11_handle)
        .expect("Failed to create first window");

    let mode = Mode {
        size: (window.size().w as i32, window.size().h as i32).into(),
        refresh: 144_000,
    };

    let output = Output::new(
        "x11".to_string(),
        PhysicalProperties {
            size: (1000, 1000).into(),
            subpixel: Subpixel::Unknown,
            make: "Veshell".into(),
            model: "x11".into(),
        },
    );
    let _global = output.create_global::<State<X11Data>>(&display_handle);
    output.change_current_state(
        Some(mode),
        None,
        Some(Scale::Fractional(1.0)),
        Some((0, 0).into()),
    );
    output.set_preferred(mode);
    let damage_tracker = OutputDamageTracker::from_output(&output);

    let skip_vulkan = std::env::var("ANVIL_NO_VULKAN")
        .map(|x| {
            x == "1"
                || x.to_lowercase() == "true"
                || x.to_lowercase() == "yes"
                || x.to_lowercase() == "y"
        })
        .unwrap_or(false);

    let vulkan_allocator = if !skip_vulkan {
        vulkan::Instance::new(Version::VERSION_1_2, None)
            .ok()
            .and_then(|instance| {
                vulkan::PhysicalDevice::enumerate(&instance)
                    .ok()
                    .and_then(|devices| {
                        devices
                            .filter(|phd| phd.has_device_extension(ext::physical_device_drm::NAME))
                            .find(|phd| {
                                phd.primary_node().unwrap() == Some(node)
                                    || phd.render_node().unwrap() == Some(node)
                            })
                    })
            })
            .and_then(|physical_device| {
                VulkanAllocator::new(
                    &physical_device,
                    ImageUsageFlags::COLOR_ATTACHMENT | ImageUsageFlags::SAMPLED,
                )
                .ok()
            })
    } else {
        None
    };

    let x11_surface = match vulkan_allocator {
        // Create the surface for the window.
        Some(vulkan_allocator) => x11_handle
            .create_surface(
                &window,
                DmabufAllocator(vulkan_allocator),
                egl_context
                    .dmabuf_render_formats()
                    .iter()
                    .map(|format| format.modifier),
            )
            .expect("Failed to create X11 surface"),
        None => x11_handle
            .create_surface(
                &window,
                DmabufAllocator(GbmAllocator::new(
                    gbm_device.clone(),
                    GbmBufferFlags::RENDERING,
                )),
                egl_context
                    .dmabuf_render_formats()
                    .iter()
                    .map(|format| format.modifier),
            )
            .expect("Failed to create X11 surface"),
    };

    let mut gles_renderer =
        unsafe { GlesRenderer::new(egl_context) }.expect("Failed to initialize GLES");

    if gles_renderer.bind_wl_display(&display_handle).is_ok() {
        info!("EGL hardware-acceleration enabled");
    }

    let dmabuf_formats = gles_renderer.dmabuf_formats();
    let dmabuf_default_feedback = DmabufFeedbackBuilder::new(node.dev_id(), dmabuf_formats.clone())
        .build()
        .unwrap();
    let mut dmabuf_state = DmabufState::new();
    let _dmabuf_global = dmabuf_state.create_global_with_default_feedback::<State<X11Data>>(
        &display.handle(),
        &dmabuf_default_feedback,
    );

    let dmabuf_allocator: Box<dyn Allocator<Buffer = Dmabuf, Error = AnyError>> = {
        let gbm_allocator = GbmAllocator::new(gbm_device.clone(), GbmBufferFlags::RENDERING);
        Box::new(DmabufAllocator(gbm_allocator))
    };

    let modifiers = dmabuf_formats
        .iter()
        .map(|format| format.modifier)
        .collect::<Vec<_>>();
    let size = window.size();

    /* let swapchain = Swapchain::new(
        dmabuf_allocator,
        size.w as u32,
        size.h as u32,
        Fourcc::Argb8888,
        modifiers,
    ); */

    let settings_manager = settings::SettingsManager::new(
        event_loop.handle(),
        |data: &mut State<X11Data>| {
            let settings = data.settings_manager.get_settings();
            data.apply_veshell_settings(&settings);
        },
        |_data, monitor_name| {
            info!("Monitor settings updated of {}", monitor_name);
        },
    );

    let mut state = State::new(
        display,
        event_loop.handle(),
        X11Data {
            render: false,
            x11_surface,
            renderer: gles_renderer,
            gbm_device,
            damage_tracker,
        },
        Some(dmabuf_state),
        settings_manager,
    );

    state.gl = Some(Gles2::load_with(
        |s| unsafe { egl::get_proc_address(s) } as *const _
    ));

    let (
        flutter_engine,
        EmbedderChannels {
            rx_present,
            rx_request_fbo,
            tx_fbo,
            tx_output_height,
            rx_baton,
        },
    ) = FlutterEngine::new(&mut state).unwrap();
    state.tx_fbo = Some(tx_fbo.clone());

    state.flutter_engine = Some(flutter_engine);

    tx_output_height.send(size.h).unwrap();
    state.space.map_output(&output, (0, 0));
    let output_clone = output.clone();

    state
        .flutter_engine_mut()
        .send_window_metrics((size.w as u32, size.h as u32).into())
        .unwrap();

    state
        .flutter_engine_mut()
        .add_view(0, size.w as usize, size.h as usize);

    // Mandatory formats by the Wayland spec.
    // TODO: Add more formats based on the GLES version.
    state
        .shm_state
        .update_formats([wl_shm::Format::Argb8888, wl_shm::Format::Xrgb8888]);

    event_loop
        .handle()
        .insert_source(
            x11_backend,
            move |event, _, data: &mut State<X11Data>| match event {
                X11Event::CloseRequested { .. } => {
                    data.running.store(false, Ordering::SeqCst);
                }

                X11Event::Resized { new_size, .. } => {
                    let size = { (new_size.w as i32, new_size.h as i32).into() };

                    output_clone.change_current_state(
                        Some(Mode {
                            size,
                            refresh: 144_000,
                        }),
                        None,
                        None,
                        Some((0, 0).into()),
                    );
                    output_clone.set_preferred(mode);

                    let _ = tx_output_height.send(new_size.h);
                    data.flutter_engine()
                        .send_window_metrics((size.w as u32, size.h as u32).into())
                        .unwrap();

                    let monitors = data.space.outputs().cloned().collect::<Vec<_>>();
                    data.flutter_engine_mut()
                        .resizeView(view_id, size.w as u32, size.h as u32);

                    data.flutter_engine_mut().monitor_layout_changed(monitors);
                    data.backend_data.render = true;
                }

                X11Event::PresentCompleted { .. } | X11Event::Refresh { .. } => {
                    data.is_next_flutter_frame_scheduled = false;
                    data.backend_data.render = true;
                    let drained: Vec<_> = data.batons.drain(..).collect(); // Mutable borrow ends here

                    for baton in drained {
                        data.flutter_engine().on_vsync(baton, 144_000).unwrap();
                    }
                }

                X11Event::Input { event, .. } => match event {
                    InputEvent::DeviceAdded { device: _ } => {}
                    InputEvent::DeviceRemoved { device: _ } => {}
                    InputEvent::Keyboard { event } => {
                        let keyboard = data.keyboard.clone();

                        // Ignore release events for keys that are not pressed.
                        // This can happen when using Alt+Tab to switch windows and focus the compositor
                        // Flutter doesn't expect to receive release events for keys that are not pressed.
                        if event.state() == KeyState::Released
                            && !keyboard.pressed_keys().contains(&event.key_code())
                        {
                            info!(
                                "Ignoring key {:?} release event because it was not pressed.",
                                event.key_code()
                            );
                            return;
                        }
                        handle_keyboard_event(
                            data,
                            event.key_code(),
                            event.state(),
                            event.time_msec(),
                        );
                    }
                    InputEvent::PointerMotion { event } => {
                        data.on_pointer_motion::<X11Input>(event, 0)
                    }
                    InputEvent::PointerMotionAbsolute { event } => {
                        data.on_pointer_motion_absolute::<X11Input>(event, 0)
                    }
                    InputEvent::PointerButton { event } => {
                        data.on_pointer_button::<X11Input>(event, 0)
                    }
                    InputEvent::PointerAxis { event } => data.on_pointer_axis::<X11Input>(event, 0),
                    InputEvent::GestureSwipeBegin { event: _ } => {}
                    InputEvent::GestureSwipeUpdate { event: _ } => {}
                    InputEvent::GestureSwipeEnd { event: _ } => {}
                    InputEvent::GesturePinchBegin { event: _ } => {}
                    InputEvent::GesturePinchUpdate { event: _ } => {}
                    InputEvent::GesturePinchEnd { event: _ } => {}
                    InputEvent::GestureHoldBegin { event: _ } => {}
                    InputEvent::GestureHoldEnd { event: _ } => {}
                    InputEvent::TouchDown { event: _ } => {}
                    InputEvent::TouchMotion { event: _ } => {}
                    InputEvent::TouchUp { event: _ } => {}
                    InputEvent::TouchCancel { event: _ } => {}
                    InputEvent::TouchFrame { event: _ } => {}
                    InputEvent::TabletToolAxis { event: _ } => {}
                    InputEvent::TabletToolProximity { event: _ } => {}
                    InputEvent::TabletToolTip { event: _ } => {}
                    InputEvent::TabletToolButton { event: _ } => {}
                    InputEvent::SwitchToggle { event: _ } => {}
                    InputEvent::Special(_) => {}
                },
                X11Event::Focus { focused: false, .. } => data.release_all_keys(),
                _ => {}
            },
        )
        .expect("Failed to insert X11 Backend into event loop");

    event_loop
        .handle()
        .insert_source(rx_baton, move |baton, _, data| {
            if let CalloopEvent::Msg(baton) = baton {
                data.batons.push(baton);
            }
        })
        .unwrap();

    state::State::<X11Data>::start_xwayland(&mut state);

    while state.running.load(Ordering::SeqCst) {
        if state.backend_data.render {
            let last_rendered_slot = state.backend_data.last_rendered_slot.as_mut();

            let (mut buffer, age) = state
                .backend_data
                .x11_surface
                .buffer()
                .expect("gbm device was destroyed");
            let mut fb = match state.backend_data.renderer.bind(&mut buffer) {
                Ok(fb) => fb,
                Err(err) => {
                    error!("Error while binding buffer: {}", err);
                    profiling::finish_frame!();
                    continue;
                }
            };

            let slot = if let Some(ref slot) = last_rendered_slot {
                slot
            } else {
                // Flutter hasn't rendered anything yet. Render a solid color to schedule the next VBLANK.
                let render_res = state
                    .backend_data
                    .damage_tracker
                    .render_output::<TextureRenderElement<_>, _>(
                        &mut state.backend_data.renderer,
                        &mut fb,
                        age.into(),
                        &[],
                        [0.0, 0.0, 0.0, 0.0],
                    );
                match render_res {
                    Ok(render_output_result) => {
                        let submitted = if let Err(err) = state.backend_data.x11_surface.submit() {
                            state.backend_data.x11_surface.reset_buffers();
                            warn!("Failed to submit buffer: {}. Retrying", err);
                            false
                        } else {
                            true
                        };

                        state.backend_data.render = !submitted;
                    }
                    Err(err) => {
                        state.backend_data.x11_surface.reset_buffers();
                        error!("Rendering error: {}", err);
                        // TODO: convert RenderError into SwapBuffersError and skip temporary (will retry) and panic on ContextLost or recreate
                    }
                }
                continue;
            };

            let geometry = match state.space.output_geometry(&output.clone()) {
                Some(geometry) => geometry.to_f64(),
                None => return,
            };

            let elements = get_render_elements(
                &mut state.backend_data.renderer,
                &output.clone(),
                slot,
                geometry,
                state.clock.now(),
                &state.cursor_image_status,
                &state.cursor_state,
                state.pointer.current_location(),
                state.surface_id_under_cursor != None,
                false,
                state
                    .meta_window_state
                    .meta_windows
                    .values()
                    .filter_map(|meta_window| {
                        if meta_window.game_mode_activated {
                            Some(state.surfaces.get(&meta_window.surface_id).unwrap())
                        } else {
                            None
                        }
                    })
                    .collect::<Vec<_>>(),
            );

            let mut elements2: Vec<VeshellRenderElements<GlesRenderer>> = Vec::new();

            /* for surface in state.xdg_shell_state.toplevel_surfaces() {
                let surface = surface.wl_surface();
                let element = get_surface_elements(&mut state.backend_data.renderer, surface);
                elements2.extend(element);
            } */
            // merge both elements
            elements2.extend(elements);

            let render_res = state.backend_data.damage_tracker.render_output(
                &mut state.backend_data.renderer,
                &mut fb,
                age.into(),
                &elements2,
                [0.0, 0.0, 0.0, 0.0],
            );

            match render_res {
                Ok(render_output_result) => {
                    let submitted = if let Err(err) = state.backend_data.x11_surface.submit() {
                        state.backend_data.x11_surface.reset_buffers();
                        warn!("Failed to submit buffer: {}. Retrying", err);
                        false
                    } else {
                        true
                    };

                    state.backend_data.render = !submitted;
                }
                Err(err) => {
                    #[cfg(feature = "debug")]
                    if let Some(renderdoc) = state.renderdoc.as_mut() {
                        renderdoc.discard_frame_capture(
                            backend_data.renderer.egl_context().get_context_handle(),
                            std::ptr::null(),
                        );
                    }

                    state.backend_data.x11_surface.reset_buffers();
                    error!("Rendering error: {}", err);
                    // TODO: convert RenderError into SwapBuffersError and skip temporary (will retry) and panic on ContextLost or recreate
                }
            }

            let start_time = std::time::Instant::now();
            for surface in state.xdg_shell_state.toplevel_surfaces() {
                send_frames_surface_tree(
                    surface.wl_surface(),
                    start_time.elapsed().as_millis() as u32,
                );
            }
            for surface in state.xdg_popups.values() {
                send_frames_surface_tree(
                    surface.wl_surface(),
                    start_time.elapsed().as_millis() as u32,
                );
            }
            for surface in state.x11_surface_per_wl_surface.keys() {
                send_frames_surface_tree(surface, start_time.elapsed().as_millis() as u32);
            }
        }
        let result = event_loop.dispatch(None, &mut state);

        if result.is_err() {
            state.running.store(false, Ordering::SeqCst);
        } else {
            display_handle.flush_clients().unwrap();
        }
    }

    // Avoid indefinite hang in the Flutter render thread waiting for new fbo.
    drop(tx_fbo);
}

pub struct X11Data {
    render: bool,
    pub x11_surface: X11Surface,
    renderer: GlesRenderer,
    gbm_device: gbm::Device<DeviceFd>,
    damage_tracker: OutputDamageTracker,
}

impl Backend for X11Data {
    fn seat_name(&self) -> String {
        "x11".to_string()
    }

    fn get_session(&self) -> smithay::backend::session::libseat::LibSeatSession {
        unreachable!("X11 backend does not support libseat")
    }

    fn with_primary_renderer_mut<T>(
        &mut self,
        f: impl FnOnce(&mut GlesRenderer) -> T,
    ) -> Option<T> {
        Some(f(&mut self.renderer))
    }

    fn new_swapchain(
        &mut self,
        width: u32,
        height: u32,
    ) -> Swapchain<Box<dyn Allocator<Buffer = Dmabuf, Error = AnyError> + 'static>> {
        let dmabuf_formats = self.renderer.dmabuf_formats();
        let dmabuf_allocator: Box<dyn Allocator<Buffer = Dmabuf, Error = AnyError>> = {
            let gbm_allocator =
                GbmAllocator::new(self.gbm_device.clone(), GbmBufferFlags::RENDERING);
            Box::new(DmabufAllocator(gbm_allocator))
        };
        let modifiers = dmabuf_formats
            .iter()
            .map(|format| format.modifier)
            .collect::<Vec<_>>();
        Swapchain::new(dmabuf_allocator, width, height, Fourcc::Argb8888, modifiers)
    }
}
