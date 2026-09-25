use std::os::fd::OwnedFd;
use std::sync::atomic::Ordering;

use smithay::backend::allocator::dmabuf::{AnyError, Dmabuf, DmabufAllocator};
use smithay::backend::allocator::gbm::{GbmAllocator, GbmBufferFlags};
use smithay::backend::allocator::{Allocator, Fourcc, Swapchain};
use smithay::backend::egl::{self, EGLDevice};
use smithay::backend::input::{Event, InputEvent, KeyState, KeyboardKeyEvent};
use smithay::backend::renderer::damage::OutputDamageTracker;
use smithay::backend::renderer::element::texture::TextureRenderElement;
use smithay::backend::renderer::gles::ffi::Gles2;
use smithay::backend::renderer::gles::GlesRenderer;
use smithay::backend::renderer::{ImportDma, ImportEgl};
use smithay::backend::winit::{self, WinitEvent, WinitGraphicsBackend, WinitInput};
use smithay::output::{Mode, Output, PhysicalProperties, Scale, Subpixel};
use smithay::reexports::calloop::channel::Event as CalloopEvent;
use smithay::reexports::calloop::EventLoop;
use smithay::reexports::gbm;
use smithay::reexports::wayland_server::protocol::wl_shm;
use smithay::reexports::wayland_server::Display;
use smithay::utils::{DeviceFd, Transform};
use smithay::wayland::dmabuf::{
    DmabufFeedbackBuilder, DmabufGlobal, DmabufHandler, DmabufState, ImportNotifier,
};
use tracing::{error, info, warn};

use crate::flutter_engine::view::OutputViewIdWrapper;
use crate::flutter_engine::{EmbedderChannels, FlutterEngine};
use crate::keyboard::handle_keyboard_event;
use crate::settings::{self, MonitorConfiguration};
use crate::{send_frames_surface_tree, State};

use super::render::get_render_elements;
use super::Backend;

pub struct Winit {
    backend: WinitGraphicsBackend<GlesRenderer>,
    damage_tracker: OutputDamageTracker,
    output: Output,
    gbm_device: gbm::Device<DeviceFd>,
}

impl Backend for Winit {
    /// Winit has a single output/view, but it uses the same composite-time
    /// flip as DRM so the engine never applies an engine-global
    /// `surface_transformation` (see `surface_transformation` in
    /// `flutter_engine::callbacks`).
    const FLIP_FLUTTER_TEXTURE: bool = true;

    fn seat_name(&self) -> String {
        "winit".to_string()
    }

    fn get_session(&self) -> smithay::backend::session::libseat::LibSeatSession {
        unreachable!("Winit does not support libseat")
    }

    fn with_primary_renderer_mut<T>(
        &mut self,
        f: impl FnOnce(&mut smithay::backend::renderer::gles::GlesRenderer) -> T,
    ) -> Option<T> {
        Some(f(self.backend.renderer()))
    }

    fn new_swapchain(
        &mut self,
        width: u32,
        height: u32,
    ) -> Swapchain<Box<dyn Allocator<Buffer = Dmabuf, Error = AnyError> + 'static>> {
        let dmabuf_formats = self.backend.renderer().dmabuf_formats();
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

impl DmabufHandler for State<Winit> {
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
            .backend
            .renderer()
            .import_dmabuf(&dmabuf, None)
            .is_ok()
        {
            let _ = notifier.successful::<State<Winit>>();
        } else {
            notifier.failed();
        }
    }
}

pub fn run_winit_backend() -> Result<(), Box<dyn std::error::Error>> {
    let mut event_loop = EventLoop::try_new().unwrap();
    let display: Display<State<Winit>> = Display::new().unwrap();
    let mut display_handle = display.handle();

    let (mut backend, winit) = winit::init::<GlesRenderer>()?;

    // The Flutter engine renders into dmabufs, so we need a GBM allocator on
    // the same GPU that backs the winit EGL context. Derive that GPU's render
    // node from the EGL device and open it directly.
    let render_node = EGLDevice::device_for_display(backend.renderer().egl_context().display())
        .and_then(|device| device.try_get_render_node());
    let render_node = match render_node {
        Ok(Some(node)) => node,
        Ok(None) => {
            return Err(
                "winit EGL device has no DRM render node: cannot allocate Flutter buffers".into(),
            )
        }
        Err(err) => {
            return Err(format!("failed to query the winit EGL device render node: {err}").into())
        }
    };
    let render_path = render_node
        .dev_path()
        .ok_or("winit render node has no device path")?;
    let render_file = std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .open(&render_path)?;
    let gbm_device = gbm::Device::new(DeviceFd::from(OwnedFd::from(render_file)))
        .map_err(|err| format!("failed to open GBM device {}: {err}", render_path.display()))?;
    info!(?render_node, "Using render node for Flutter buffers");

    let mode = Mode {
        size: backend.window_size(),
        refresh: 60_000,
    };

    let output = Output::new(
        "winit".to_string(),
        PhysicalProperties {
            size: (0, 0).into(),
            subpixel: Subpixel::Unknown,
            make: "Veshell".into(),
            model: "Winit".into(),
            serial_number: String::new(),
        },
    );
    let _global = output.create_global::<State<Winit>>(&display_handle);
    output.change_current_state(
        Some(mode),
        Some(Transform::Flipped180),
        Some(Scale::Fractional(backend.scale_factor())),
        Some((0, 0).into()),
    );
    output.set_preferred(mode);
    let damage_tracker = OutputDamageTracker::from_output(&output);

    let dmabuf_formats = backend.renderer().dmabuf_formats();
    let dmabuf_default_feedback = DmabufFeedbackBuilder::new(render_node.dev_id(), dmabuf_formats)
        .build()
        .unwrap();
    let mut dmabuf_state = DmabufState::new();
    let _dmabuf_global = dmabuf_state.create_global_with_default_feedback::<State<Winit>>(
        &display.handle(),
        &dmabuf_default_feedback,
    );

    if backend
        .renderer()
        .bind_wl_display(&display.handle())
        .is_ok()
    {
        info!("EGL hardware-acceleration enabled");
    };

    let settings_manager = settings::SettingsManager::new(
        event_loop.handle(),
        |data: &mut State<Winit>| {
            let settings = data.settings_manager.get_settings();
            data.apply_veshell_settings(&settings);
        },
        |data: &mut State<Winit>, monitor_name| {
            info!("Monitor settings updated of {}", monitor_name);
            let config: MonitorConfiguration = data
                .settings_manager
                .get_monitor_configuration(monitor_name)
                .unwrap();
            if let Some(output) = data.get_output_by_name(monitor_name) {
                let any_changes =
                    data.apply_monitor_configuration_to_output(&output.clone(), config);

                if any_changes {
                    data.on_outputs_changed();
                }
            }
        },
    );

    let mut state = State::new(
        display,
        event_loop.handle(),
        Winit {
            backend,
            damage_tracker,
            output: output.clone(),
            gbm_device,
        },
        Some(dmabuf_state),
        settings_manager,
    );

    if let Some(monitor_setting) = state
        .settings_manager
        .get_monitor_configuration(&output.name())
    {
        state.apply_monitor_configuration_to_output(&output, monitor_setting);
    }

    state.gl = Some(Gles2::load_with(|s| unsafe {
        egl::get_proc_address(s) as *const _
    }));

    let (flutter_engine, EmbedderChannels { rx_baton }) = FlutterEngine::new(&mut state).unwrap();

    state.flutter_engine = Some(flutter_engine);

    state.map_output(&output, output.current_location());

    let view_id = state.flutter_engine_mut().add_view(0, &output);

    output
        .user_data()
        .insert_if_missing(|| OutputViewIdWrapper { view_id });

    state.on_outputs_changed();

    // Mandatory formats by the Wayland spec.
    state
        .shm_state
        .update_formats([wl_shm::Format::Argb8888, wl_shm::Format::Xrgb8888]);

    event_loop
        .handle()
        .insert_source(winit, move |event, _, data: &mut State<Winit>| {
            match event {
                WinitEvent::Resized { size, scale_factor } => {
                    let scale_changed =
                        data.backend_data.output.current_scale().fractional_scale() != scale_factor;
                    let new_scale = scale_changed.then(|| Scale::Fractional(scale_factor));

                    data.backend_data.output.change_current_state(
                        Some(Mode {
                            size,
                            refresh: 60_000,
                        }),
                        None,
                        new_scale,
                        None,
                    );

                    // The damage tracker captures the output scale/transform at
                    // creation, so it must be rebuilt when the scale changes.
                    if scale_changed {
                        data.backend_data.damage_tracker =
                            OutputDamageTracker::from_output(&data.backend_data.output);
                    }

                    data.output_layout_changed();

                    let resized_output = data.backend_data.output.clone();
                    data.flutter_engine_mut()
                        .resize_view(view_id, &resized_output)
                        .unwrap();

                    data.on_outputs_changed();
                    data.backend_data.backend.window().request_redraw();
                }
                WinitEvent::Input(event) => match event {
                    InputEvent::DeviceAdded { device: _ } => {}
                    InputEvent::DeviceRemoved { device: _ } => {}
                    InputEvent::Keyboard { event } => {
                        crate::idle::on_activity(data);
                        let keyboard = data.keyboard.clone();

                        // Ignore release events for keys that are not pressed.
                        // This can happen when using Alt+Tab to switch windows
                        // and focus the compositor. Flutter doesn't expect to
                        // receive release events for keys that are not pressed.
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
                            false,
                        );
                    }
                    InputEvent::PointerMotion { event } => {
                        crate::idle::on_activity(data);
                        data.on_pointer_motion::<WinitInput>(event, 0, view_id)
                    }
                    InputEvent::PointerMotionAbsolute { event } => {
                        crate::idle::on_activity(data);
                        data.on_pointer_motion_absolute::<WinitInput>(event, 0, view_id)
                    }
                    InputEvent::PointerButton { event } => {
                        crate::idle::on_activity(data);
                        data.on_pointer_button::<WinitInput>(event, 0, view_id)
                    }
                    InputEvent::PointerAxis { event } => {
                        crate::idle::on_activity(data);
                        data.on_pointer_axis::<WinitInput>(event, 0, view_id)
                    }
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
                WinitEvent::Focus(focused) => {
                    if !focused {
                        data.release_all_keys();
                    }
                }
                WinitEvent::Redraw => {
                    let output = data.backend_data.output.clone();
                    let age = data.backend_data.backend.buffer_age().unwrap_or(0);
                    let geometry = match data.space.output_geometry(&output) {
                        Some(geometry) => geometry.to_f64(),
                        None => return,
                    };

                    let render_result = match data.backend_data.backend.bind() {
                        Ok((renderer, mut framebuffer)) => {
                            let slot = data
                                .flutter_engine
                                .as_ref()
                                .unwrap()
                                .views_management
                                .views
                                .get(&view_id)
                                .and_then(|view| view.last_rendered_slot.as_ref());

                            Some(match slot {
                                Some(slot) => {
                                    let elements = get_render_elements(
                                        renderer,
                                        &output,
                                        slot,
                                        geometry,
                                        data.clock.now(),
                                        &data.cursor_image_status,
                                        &data.cursor_state,
                                        data.pointer.current_location(),
                                        data.surface_id_under_cursor != None,
                                        <Winit as Backend>::FLIP_FLUTTER_TEXTURE,
                                        data.idle.dim_alpha(),
                                        data.meta_window_state
                                            .meta_windows
                                            .values()
                                            .filter_map(|meta_window| {
                                                meta_window
                                                    .game_mode_activated
                                                    .then(|| {
                                                        data.surfaces.get(&meta_window.surface_id)
                                                    })
                                                    .flatten()
                                            })
                                            .collect::<Vec<_>>(),
                                        data.capture_state.session.as_ref().filter(|session| {
                                            session.output.name() == output.name()
                                        }),
                                        data.capture_state
                                            .recording_session
                                            .as_ref()
                                            .filter(|recording| {
                                                recording.output_name() == output.name()
                                            })
                                            .map(|recording| recording.chip_data()),
                                    );

                                    data.backend_data.damage_tracker.render_output(
                                        renderer,
                                        &mut framebuffer,
                                        age,
                                        &elements,
                                        [0.0, 0.0, 0.0, 0.0],
                                    )
                                }
                                // Flutter hasn't rendered anything yet: clear
                                // the window to keep the host scheduling us.
                                None => data
                                    .backend_data
                                    .damage_tracker
                                    .render_output::<TextureRenderElement<_>, _>(
                                        renderer,
                                        &mut framebuffer,
                                        age,
                                        &[],
                                        [0.0, 0.0, 0.0, 0.0],
                                    ),
                            })
                        }
                        Err(err) => {
                            error!("Failed to bind winit backend: {}", err);
                            None
                        }
                    };

                    if let Some(render_result) = render_result {
                        match render_result {
                            Ok(_) => {
                                if let Err(err) = data.backend_data.backend.submit(None) {
                                    warn!("Failed to submit winit buffer: {}", err);
                                }

                                let drained: Vec<_> = data.batons.drain(..).collect();
                                for baton in drained {
                                    data.flutter_engine().on_vsync(baton, 60_000).unwrap();
                                }

                                let frame_timestamp = data.frame_timestamp_millis();
                                for surface in data.xdg_shell_state.toplevel_surfaces() {
                                    send_frames_surface_tree(surface.wl_surface(), frame_timestamp);
                                }
                                for surface in data.xdg_popups.values() {
                                    send_frames_surface_tree(surface.wl_surface(), frame_timestamp);
                                }
                                for surface in data.x11_surface_per_wl_surface.keys() {
                                    send_frames_surface_tree(surface, frame_timestamp);
                                }

                                data.space.refresh();
                            }
                            Err(err) => {
                                error!("Rendering error: {}", err);
                            }
                        }
                    }

                    // Ask for another redraw to keep presenting frames.
                    data.backend_data.backend.window().request_redraw();
                }
                WinitEvent::CloseRequested => {
                    data.running.store(false, Ordering::SeqCst);
                }
            };
        })?;

    event_loop
        .handle()
        .insert_source(rx_baton, move |baton, _, data| {
            if let CalloopEvent::Msg(baton) = baton {
                data.batons.push(baton);
            }
        })
        .unwrap();

    State::<Winit>::start_xwayland(&mut state);

    while state.running.load(Ordering::SeqCst) {
        let result = event_loop.dispatch(None, &mut state);

        if result.is_err() {
            state.running.store(false, Ordering::SeqCst);
        } else {
            display_handle.flush_clients().unwrap();
        }
    }
    Ok(())
}
