use std::sync::atomic::Ordering;

use log::{error, warn};
use smithay::backend::allocator::dmabuf::Dmabuf;
use smithay::backend::input::{Event, InputEvent, KeyboardKeyEvent};
use smithay::backend::renderer::gles::ffi::Gles2;
use smithay::backend::renderer::gles::GlesRenderer;
use smithay::backend::renderer::{ImportDma, ImportEgl};
use smithay::backend::x11::X11Input;
use smithay::delegate_dmabuf;
use smithay::output::{Output, PhysicalProperties, Subpixel};
use smithay::reexports::ash::ext;
use smithay::reexports::calloop::channel::Event::Msg;
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
use tracing::info;

use crate::flutter_engine::FlutterEngine;
use crate::keyboard::handle_keyboard_event;
use crate::state;
use crate::{flutter_engine::EmbedderChannels, send_frames_surface_tree, State};

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
    output.change_current_state(Some(mode), None, None, Some((0, 0).into()));
    output.set_preferred(mode);

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
                DmabufAllocator(GbmAllocator::new(gbm_device, GbmBufferFlags::RENDERING)),
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
    let dmabuf_default_feedback = DmabufFeedbackBuilder::new(node.dev_id(), dmabuf_formats)
        .build()
        .unwrap();
    let mut dmabuf_state = DmabufState::new();
    let _dmabuf_global = dmabuf_state.create_global_with_default_feedback::<State<X11Data>>(
        &display.handle(),
        &dmabuf_default_feedback,
    );

    let mut state = State::new(
        display,
        event_loop.handle(),
        X11Data {
            x11_surface,
            renderer: gles_renderer,
        },
        Some(dmabuf_state),
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

    let size = window.size();
    tx_output_height.send(size.h).unwrap();
    state.space.map_output(&output, (0, 0));
    let output_clone = output.clone();

    state
        .flutter_engine_mut()
        .send_window_metrics((size.w as u32, size.h as u32).into())
        .unwrap();

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
                    data.flutter_engine_mut().monitor_layout_changed(monitors);
                }

                X11Event::PresentCompleted { .. } | X11Event::Refresh { .. } => {
                    data.is_next_flutter_frame_scheduled = false;
                    let drained: Vec<_> = data.batons.drain(..).collect(); // Mutable borrow ends here

                    for baton in drained {
                        data.flutter_engine().on_vsync(baton, 144_000).unwrap();
                    }
                    let start_time = std::time::Instant::now();
                    for surface in data.xdg_shell_state.toplevel_surfaces() {
                        send_frames_surface_tree(
                            surface.wl_surface(),
                            start_time.elapsed().as_millis() as u32,
                        );
                    }
                    for surface in data.xdg_popups.values() {
                        send_frames_surface_tree(
                            surface.wl_surface(),
                            start_time.elapsed().as_millis() as u32,
                        );
                    }
                    for surface in data.x11_surface_per_wl_surface.keys() {
                        send_frames_surface_tree(surface, start_time.elapsed().as_millis() as u32);
                    }
                }

                X11Event::Input { event, .. } => {
                    match event {
                        InputEvent::DeviceAdded { mut device } => {

                        },
                        InputEvent::DeviceRemoved { device } => {},
                        InputEvent::Keyboard { event } => {
                            handle_keyboard_event(
                                data,
                                event.key_code(),
                                event.state(),
                                event.time_msec(),
                            );
                        },
                        InputEvent::PointerMotion { event } => data.on_pointer_motion::<X11Input>(event),
                        InputEvent::PointerMotionAbsolute { event } => data.on_pointer_motion_absolute::<X11Input>(event),
                        InputEvent::PointerButton { event } => data.on_pointer_button::<X11Input>(event),
                        InputEvent::PointerAxis { event } => data.on_pointer_axis::<X11Input>(event),
                        InputEvent::GestureSwipeBegin { event } => {},
                        InputEvent::GestureSwipeUpdate { event } => {},
                        InputEvent::GestureSwipeEnd { event } => {},
                        InputEvent::GesturePinchBegin { event } => {},
                        InputEvent::GesturePinchUpdate { event } => {},
                        InputEvent::GesturePinchEnd { event } => {},
                        InputEvent::GestureHoldBegin { event } => {},
                        InputEvent::GestureHoldEnd { event } => {},
                        InputEvent::TouchDown { event } => {},
                        InputEvent::TouchMotion { event } => {},
                        InputEvent::TouchUp { event } => {},
                        InputEvent::TouchCancel { event } => {},
                        InputEvent::TouchFrame { event } => {},
                        InputEvent::TabletToolAxis { event } => {},
                        InputEvent::TabletToolProximity { event } => {},
                        InputEvent::TabletToolTip { event } => {},
                        InputEvent::TabletToolButton { event } => {},
                        InputEvent::SwitchToggle { event } => {},
                        InputEvent::Special(_) => {},
                    }
                },
                X11Event::Focus { focused: false, .. } => data.release_all_keys(),
                _ => {}
            },
        )
        .expect("Failed to insert X11 Backend into event loop");

    event_loop
        .handle()
        .insert_source(rx_baton, move |baton, _, data| {
            if let Msg(baton) = baton {
                if data.is_next_flutter_frame_scheduled {
                    data.batons.push(baton);
                    return;
                }
                data.flutter_engine().on_vsync(baton, 144_000).unwrap();
            }
        })
        .unwrap();

    event_loop
        .handle()
        .insert_source(rx_request_fbo, move |_, _, data| {
            match data.backend_data.x11_surface.buffer() {
                Ok((dmabuf, _age)) => {
                    let _ = data.tx_fbo.as_ref().unwrap().send(Some(dmabuf));
                }
                Err(err) => {
                    error!("{err}");
                    let _ = data.tx_fbo.as_ref().unwrap().send(None);
                }
            }
        })
        .unwrap();

    event_loop
        .handle()
        .insert_source(rx_present, move |_, _, data| {
            data.is_next_flutter_frame_scheduled = true;
            if let Err(err) = data.backend_data.x11_surface.submit() {
                data.backend_data.x11_surface.reset_buffers();
                warn!("Failed to submit buffer: {}. Retrying", err);
            };
        })
        .unwrap();

    state::State::<X11Data>::start_xwayland(&mut state);

    while state.running.load(Ordering::SeqCst) {
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
    pub x11_surface: X11Surface,
    renderer: GlesRenderer,
}

impl Backend for X11Data {
    fn seat_name(&self) -> String {
        "x11".to_string()
    }

    fn get_session(&self) -> smithay::backend::session::libseat::LibSeatSession {
        unreachable!("X11 backend does not support libseat")
    }

    fn with_primary_renderer<T>(&mut self, f: impl FnOnce(&GlesRenderer) -> T) -> Option<T> {
        Some(f(&self.renderer))
    }

    fn with_primary_renderer_mut<T>(
        &mut self,
        f: impl FnOnce(&mut GlesRenderer) -> T,
    ) -> Option<T> {
        Some(f(&mut self.renderer))
    }
}
