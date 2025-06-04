use std::sync::atomic::Ordering;

use smithay::{
    backend::{
        allocator::dmabuf::Dmabuf,
        egl::EGLDevice,
        input::{Event, InputEvent, KeyboardKeyEvent},
        renderer::{
            damage::OutputDamageTracker, element::surface::WaylandSurfaceRenderElement,
            gles::GlesRenderer, ImportDma, ImportEgl,
        },
        winit::{self, WinitEvent, WinitGraphicsBackend, WinitInput},
    },
    delegate_dmabuf,
    output::{Mode, Output, PhysicalProperties, Subpixel},
    reexports::{calloop::EventLoop, wayland_server::Display},
    utils::{Rectangle, Transform},
    wayland::dmabuf::{
        DmabufFeedbackBuilder, DmabufGlobal, DmabufHandler, DmabufState, ImportNotifier,
    },
};
use tracing::{info, warn};

use crate::{
    flutter_engine::{
        embedder::FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse, EmbedderChannels,
        FlutterEngine,
    },
    keyboard::handle_keyboard_event,
    settings,
    state::State,
};

use super::Backend;

pub struct Winit {
    backend: WinitGraphicsBackend<GlesRenderer>,
    damage_tracker: OutputDamageTracker,
    output: Output,
}

impl Backend for Winit {
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
delegate_dmabuf!(State<Winit>);

pub fn run_winit_backend() -> Result<(), Box<dyn std::error::Error>> {
    let mut event_loop = EventLoop::try_new().unwrap();
    let display: Display<State<Winit>> = Display::new().unwrap();
    let mut display_handle = display.handle();

    let (mut backend, winit) = winit::init::<GlesRenderer>()?;

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
        },
    );

    let _global = output.create_global::<State<Winit>>(&display_handle);

    output.change_current_state(
        Some(mode),
        Some(Transform::Flipped180),
        None,
        Some((0, 0).into()),
    );
    output.set_preferred(mode);

    let render_node = EGLDevice::device_for_display(backend.renderer().egl_context().display())
        .and_then(|device| device.try_get_render_node());

    let dmabuf_default_feedback = match render_node {
        Ok(Some(node)) => {
            let dmabuf_formats = backend.renderer().dmabuf_formats();
            let dmabuf_default_feedback = DmabufFeedbackBuilder::new(node.dev_id(), dmabuf_formats)
                .build()
                .unwrap();

            Some(dmabuf_default_feedback)
        }
        Ok(None) => {
            warn!("failed to query render node, dmabuf will use v3");
            None
        }
        Err(err) => {
            warn!(?err, "failed to egl device for display, dmabuf will use v3");
            None
        }
    };

    // if we failed to build dmabuf feedback we fall back to dmabuf v3
    // Note: egl on Mesa requires either v4 or wl_drm (initialized with bind_wl_display)
    let (dmabuf_state, _dmabuf_global, _dmabuf_default_feedback) =
        if let Some(default_feedback) = dmabuf_default_feedback {
            let mut dmabuf_state = DmabufState::new();
            let dmabuf_global = dmabuf_state.create_global_with_default_feedback::<State<Winit>>(
                &display.handle(),
                &default_feedback,
            );
            (dmabuf_state, dmabuf_global, Some(default_feedback))
        } else {
            let dmabuf_formats = backend.renderer().dmabuf_formats();
            let mut dmabuf_state = DmabufState::new();
            let dmabuf_global =
                dmabuf_state.create_global::<State<Winit>>(&display.handle(), dmabuf_formats);
            (dmabuf_state, dmabuf_global, None)
        };

    if backend
        .renderer()
        .bind_wl_display(&display.handle())
        .is_ok()
    {
        info!("EGL hardware-acceleration enabled");
    };

    /*     let dmabuf_allocator: Box<dyn Allocator<Buffer = Dmabuf, Error = AnyError>> = {
        let gbm_allocator = GbmAllocator::new(gbm_device.clone(), GbmBufferFlags::RENDERING);
        Box::new(DmabufAllocator(gbm_allocator))
    };

    let modifiers = renderer
        .egl_context()
        .dmabuf_texture_formats()
        .iter()
        .map(|format| format.modifier)
        .collect::<Vec<_>>();

    let swapchain = Some(Swapchain::new(
        dmabuf_allocator,
        0,
        0,
        Fourcc::Argb8888,
        modifiers,
    )); */

    let settings_manager = settings::SettingsManager::new(
        event_loop.handle(),
        |data: &mut State<Winit>| {
            let settings = data.settings_manager.get_settings();
            data.apply_veshell_settings(&settings);
        },
        |_data, monitor_name| {
            info!("Monitor settings updated of {}", monitor_name);
        },
    );

    let mut damage_tracker = OutputDamageTracker::from_output(&output);

    event_loop
        .handle()
        .insert_source(winit, move |event, _, data| {
            let display = &mut data.display_handle;

            match event {
                WinitEvent::Resized { size, .. } => {
                    data.backend_data.output.change_current_state(
                        Some(Mode {
                            size,
                            refresh: 60_000,
                        }),
                        None,
                        None,
                        None,
                    );
                }
                WinitEvent::Input(event) => match event {
                    InputEvent::DeviceAdded { mut device } => {}
                    InputEvent::DeviceRemoved { device: _ } => {}
                    InputEvent::Keyboard { event } => {
                        handle_keyboard_event(
                            data,
                            event.key_code(),
                            event.state(),
                            event.time_msec(),
                        );
                    }
                    InputEvent::PointerMotion { event } => {}
                    InputEvent::PointerMotionAbsolute { event } => {
                        data.on_pointer_motion_absolute::<WinitInput>(event, 0)
                    }
                    InputEvent::PointerButton { event } => data.on_pointer_button::<WinitInput>(
                        event,
                        FlutterPointerDeviceKind_kFlutterPointerDeviceKindMouse,
                        0,
                    ),
                    InputEvent::PointerAxis { event } => {
                        data.on_pointer_axis::<WinitInput>(event, 0)
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
                WinitEvent::Redraw => {
                    let size = data.backend_data.backend.window_size();
                    let damage = Rectangle::from_size(size);

                    {
                        let (renderer, mut framebuffer) = data.backend_data.backend.bind().unwrap();
                        smithay::desktop::space::render_output::<
                            _,
                            WaylandSurfaceRenderElement<GlesRenderer>,
                            _,
                            _,
                        >(
                            &data.backend_data.output,
                            renderer,
                            &mut framebuffer,
                            1.0,
                            0,
                            [&data.space],
                            &[],
                            &mut data.backend_data.damage_tracker,
                            [0.1, 0.1, 0.1, 1.0],
                        )
                        .unwrap();
                    }
                    data.backend_data.backend.submit(Some(&[damage])).unwrap();

                    /*                     state.space.elements().for_each(|window| {
                        window.send_frame(
                            &output,
                            state.start_time.elapsed(),
                            Some(Duration::ZERO),
                            |_, _| Some(output.clone()),
                        )
                    }); */

                    data.space.refresh();

                    let _ = display.flush_clients();

                    // Ask for redraw to schedule new frame.
                    data.backend_data.backend.window().request_redraw();
                }
                WinitEvent::CloseRequested => {
                    data.running.store(false, Ordering::SeqCst);
                }
                _ => (),
            };
        })?;

    let mut state = State::new(
        display,
        event_loop.handle(),
        Winit {
            backend,
            damage_tracker,
            output,
        },
        Some(dmabuf_state),
        settings_manager,
    );

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

    state.space.map_output(&state.backend_data.output, (0, 0));

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
