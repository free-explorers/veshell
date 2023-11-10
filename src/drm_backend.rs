use std::collections::HashMap;
use std::os::fd::{AsRawFd, FromRawFd};
use std::path::Path;
use std::sync::atomic::Ordering;

use rustix::fs::OFlags;
use smithay::backend::allocator::{Allocator, Fourcc, Slot, Swapchain};
use smithay::backend::allocator::dmabuf::{AnyError, AsDmabuf, Dmabuf, DmabufAllocator};
use smithay::backend::allocator::gbm::{GbmAllocator, GbmBufferFlags};
use smithay::backend::allocator::gbm::GbmDevice;
use smithay::backend::drm::{CreateDrmNodeError, DrmDevice, DrmDeviceFd, DrmError, DrmEvent, DrmNode, NodeType};
use smithay::backend::drm::compositor::DrmCompositor;
use smithay::backend::egl;
use smithay::backend::egl::{EGLContext, EGLDevice, EGLDisplay};
use smithay::backend::libinput::{LibinputInputBackend, LibinputSessionInterface};
use smithay::backend::renderer::element::Kind;
use smithay::backend::renderer::element::texture::{TextureBuffer, TextureRenderElement};
use smithay::backend::renderer::gles::{GlesRenderer, GlesTexture};
use smithay::backend::renderer::gles::ffi::Gles2;
use smithay::backend::renderer::ImportDma;
use smithay::backend::session::{libseat, Session};
use smithay::backend::session::libseat::LibSeatSession;
use smithay::backend::udev::{all_gpus, primary_gpu, UdevBackend, UdevEvent};
use smithay::desktop::utils::OutputPresentationFeedback;
use smithay::output::{Output, PhysicalProperties, Subpixel};
use smithay::output::Mode;
use smithay::reexports::calloop::channel::Event;
use smithay::reexports::calloop::EventLoop;
use smithay::reexports::calloop::RegistrationToken;
use smithay::reexports::drm::control::{connector, crtc, Device, ModeTypeFlags};
use smithay::reexports::drm::Device as _;
use smithay::reexports::input::Libinput;
use smithay::reexports::wayland_server::backend::GlobalId;
use smithay::reexports::wayland_server::Display;
use smithay::reexports::wayland_server::DisplayHandle;
use smithay::reexports::wayland_server::protocol::wl_shm;
use smithay::utils::{DeviceFd, Point, Transform};
use smithay::wayland::dmabuf::{DmabufFeedbackBuilder, DmabufState};
use smithay::wayland::drm_lease::DrmLease;
use tracing::{error, info, warn};

use smithay_drm_extras::drm_scanner::{DrmScanEvent, DrmScanner};
use smithay_drm_extras::edid::EdidInfo;

use crate::{Backend, CalloopData, flutter_engine::EmbedderChannels, ServerState};
use crate::flutter_engine::FlutterEngine;
use crate::flutter_engine::platform_channels::binary_messenger::BinaryMessenger;
use crate::input_handling::handle_input;

pub struct DrmBackend {
    pub session: LibSeatSession,
    gpus: HashMap<DrmNode, GpuData>,
    primary_gpu: DrmNode,
    pointer_images: Vec<(xcursor::parser::Image, TextureBuffer<GlesTexture>)>,
    pointer_image: crate::cursor::Cursor,
}

impl Backend for DrmBackend {
    fn seat_name(&self) -> String {
        self.session.seat()
    }
}

impl DrmBackend {
    fn get_gpu_data(&self) -> &GpuData {
        self.gpus.get(&self.primary_gpu).unwrap()
    }

    fn get_gpu_data_mut(&mut self) -> &mut GpuData {
        self.gpus.get_mut(&self.primary_gpu).unwrap()
    }
}

// we cannot simply pick the first supported format of the intersection of *all* formats, because:
// - we do not want something like Abgr4444, which looses color information, if something better is available
// - some formats might perform terribly
// - we might need some work-arounds, if one supports modifiers, but the other does not
//
// So lets just pick `ARGB2101010` (10-bit) or `ARGB8888` (8-bit) for now, they are widely supported.
const SUPPORTED_FORMATS: &[Fourcc] = &[
    Fourcc::Abgr2101010,
    Fourcc::Argb2101010,
    Fourcc::Abgr8888,
    Fourcc::Argb8888,
];
const SUPPORTED_FORMATS_8BIT_ONLY: &[Fourcc] = &[Fourcc::Abgr8888, Fourcc::Argb8888];

pub fn run_drm_backend() {
    let mut event_loop = EventLoop::try_new().unwrap();
    let display: Display<ServerState<DrmBackend>> = Display::new().unwrap();
    let mut display_handle = display.handle();

    let (session, _notifier) = match LibSeatSession::new() {
        Ok(ret) => ret,
        Err(err) => {
            error!("Could not initialize a session: {}", err);
            return;
        }
    };

    let primary_gpu = if let Ok(var) = std::env::var("DRM_DEVICE") {
        DrmNode::from_path(var).expect("Invalid drm device path")
    } else {
        primary_gpu(session.seat())
            .unwrap()
            .and_then(|x| DrmNode::from_path(x).ok()?.node_with_type(NodeType::Primary)?.ok())
            .unwrap_or_else(|| {
                all_gpus(session.seat())
                    .unwrap()
                    .into_iter()
                    .find_map(|x| DrmNode::from_path(x).ok())
                    .expect("No GPU!")
            })
    };
    info!("Using {} as primary gpu.", primary_gpu);

    let udev_backend = match UdevBackend::new(session.seat()) {
        Ok(ret) => ret,
        Err(err) => {
            error!(error = ?err, "Failed to initialize udev backend");
            return;
        }
    };

    let mut libinput_context = Libinput::new_with_udev::<LibinputSessionInterface<LibSeatSession>>(
        session.clone().into(),
    );
    libinput_context.udev_assign_seat(&session.seat()).unwrap();
    let libinput_backend = LibinputInputBackend::new(libinput_context.clone());

    let mut state = ServerState::new(
        display,
        event_loop.handle(),
        DrmBackend {
            session,
            gpus: HashMap::new(),
            primary_gpu,
            pointer_images: vec![],
            pointer_image: crate::cursor::Cursor::load(),
        },
        None,
    );

    // Initialize GPU state.
    state.gpu_added(primary_gpu, &primary_gpu.dev_path().unwrap()).unwrap();

    let gles_renderer = state.gles_renderer.as_ref().unwrap();
    let egl_context = gles_renderer.egl_context();

    let dmabuf_formats = egl_context.dmabuf_texture_formats()
        .iter()
        .copied()
        .collect::<Vec<_>>();
    let dmabuf_default_feedback = DmabufFeedbackBuilder::new(primary_gpu.dev_id(), dmabuf_formats)
        .build()
        .unwrap();
    let mut dmabuf_state = DmabufState::new();
    let _dmabuf_global = dmabuf_state.create_global_with_default_feedback::<ServerState<DrmBackend>>(
        &display_handle,
        &dmabuf_default_feedback,
    );

    state.dmabuf_state = Some(dmabuf_state);

    // Start the Flutter engine.
    let (
        mut flutter_engine,
        EmbedderChannels {
            rx_present,
            rx_request_fbo,
            mut tx_fbo,
            tx_output_height: _,
            rx_baton,
            rx_request_external_texture_name,
            tx_external_texture_name,
        },
    ) = FlutterEngine::new(egl_context, &state).unwrap();

    state.flutter_engine = Some(flutter_engine);

    let mut baton = None;

    // Initialize already present connectors.
    state.device_changed(primary_gpu);

    // Mandatory formats by the Wayland spec.
    // TODO: Add more formats based on the GLES version.
    state.shm_state.update_formats([
        wl_shm::Format::Argb8888,
        wl_shm::Format::Xrgb8888,
    ]);

    event_loop
        .handle()
        .insert_source(libinput_backend, move |event, _, data| {
            let _dh = data.state.display_handle.clone();
            handle_input(&event, data);
            // TODO: When the cursor moves, the cursor CRTC plane has to be updated.
            // However, we should call this only when the cursor actually moves, and not on every
            // input event.
            data.state.update_crtc_planes();
        })
        .unwrap();

    event_loop
        .handle()
        .insert_source(udev_backend, move |event, _, data| {
            if let UdevEvent::Changed { device_id } = event {
                if let Ok(node) = DrmNode::from_dev_id(device_id) {
                    data.state.device_changed(node)
                }
            }
        })
        .unwrap();

    // Mandatory formats by the Wayland spec.
    // TODO: Add more formats based on the GLES version.
    state.shm_state.update_formats([
        wl_shm::Format::Argb8888,
        wl_shm::Format::Xrgb8888,
    ]);

    event_loop.handle().insert_source(rx_baton, move |baton, _, data| {
        if let Event::Msg(baton) = baton {
            data.baton = Some(baton);
        }
        if data.state.is_next_vblank_scheduled {
            return;
        }
        if let Some(baton) = data.baton.take() {
            data.state.flutter_engine().on_vsync(baton).unwrap();
        }
    }).unwrap();

    event_loop.handle().insert_source(rx_request_fbo, move |_, _, data| {
        let gpu_data = data.state.backend_data.get_gpu_data_mut();
        let slot = gpu_data.swapchain.acquire().ok().flatten().unwrap();
        let dmabuf = slot.export().unwrap();
        gpu_data.current_slot = Some(slot);
        data.tx_fbo.send(Some(dmabuf)).unwrap();
    }).unwrap();

    event_loop.handle().insert_source(rx_present, move |_, _, data| {
        let gpu_data = data.state.backend_data.get_gpu_data_mut();
        gpu_data.last_rendered_slot = gpu_data.current_slot.take();
        data.state.update_crtc_planes();
        data.state.is_next_vblank_scheduled = true;
    }).unwrap();

    while state.running.load(Ordering::SeqCst) {
        let mut calloop_data = CalloopData {
            state,
            tx_fbo,
            baton,
        };

        let result = event_loop.dispatch(None, &mut calloop_data);

        CalloopData {
            state,
            tx_fbo,
            baton,
        } = calloop_data;

        if result.is_err() {
            state.running.store(false, Ordering::SeqCst);
        } else {
            display_handle.flush_clients().unwrap();
        }
    }

    // Avoid indefinite hang in the Flutter render thread waiting for new rbo.
    drop(tx_fbo);
}

impl ServerState<DrmBackend> {
    pub fn update_crtc_planes(&mut self) {
        let primary_gpu = self.backend_data.primary_gpu;
        let gpu_data = if let Some(gpu_data) = self.backend_data.gpus.get_mut(&primary_gpu) {
            gpu_data
        } else {
            return;
        };

        let (gles_renderer, surface, last_rendered_slot, swapchain) = (
            self.gles_renderer.as_mut().unwrap(),
            if let Some(surface) = gpu_data.surfaces.values_mut().next() {
                surface
            } else {
                return;
            },
            &mut gpu_data.last_rendered_slot,
            &mut gpu_data.swapchain,
        );

        let slot = if let Some(slot) = last_rendered_slot.as_mut() {
            slot
        } else {
            // Flutter hasn't rendered anything yet. Just draw a black frame to keep the VBlank cycle going.
            surface.compositor.render_frame::<GlesRenderer, TextureRenderElement<GlesTexture>, GlesTexture>(gles_renderer, &[], [0.0, 0.0, 0.0, 0.0]).unwrap();
            surface.compositor.queue_frame(None).unwrap();
            return;
        };

        let flutter_texture = gles_renderer.import_dmabuf(&slot.export().unwrap(), None).unwrap();
        let flutter_texture_buffer = TextureBuffer::from_texture(gles_renderer, flutter_texture, 1, Transform::Flipped180, None);
        let flutter_texture_element = TextureRenderElement::from_texture_buffer(
            Point::from((0.0, 0.0)),
            &flutter_texture_buffer,
            None,
            None,
            None,
            Kind::Unspecified,
        );

        let pointer_frame = self.backend_data
            .pointer_image
            .get_image(1, self.clock.now().try_into().unwrap());

        let cursor_position = Point::from(self.mouse_position) - Point::from((pointer_frame.xhot as f64, pointer_frame.yhot as f64));

        let pointer_images = &mut self.backend_data.pointer_images;
        let pointer_image = pointer_images
            .iter()
            .find_map(|(image, texture)| {
                if image == &pointer_frame {
                    Some(texture.clone())
                } else {
                    None
                }
            })
            .unwrap_or_else(|| {
                let texture = TextureBuffer::from_memory(
                    gles_renderer,
                    &pointer_frame.pixels_rgba,
                    Fourcc::Abgr8888,
                    (pointer_frame.width as i32, pointer_frame.height as i32),
                    false,
                    1,
                    Transform::Normal,
                    None,
                ).expect("Failed to import cursor bitmap");
                pointer_images.push((pointer_frame, texture.clone()));
                texture
            });

        let cursor_element = TextureRenderElement::from_texture_buffer(
            cursor_position,
            &pointer_image,
            None,
            None,
            None,
            Kind::Cursor,
        );

        surface.compositor.render_frame::<GlesRenderer, TextureRenderElement<GlesTexture>, GlesTexture>(
            gles_renderer,
            &[flutter_texture_element, cursor_element],
            [0.0, 0.0, 0.0, 0.0],
        ).unwrap();
        surface.compositor.queue_frame(None).unwrap();
        swapchain.submitted(slot);
    }
}

#[allow(dead_code)]
struct GpuData {
    surfaces: HashMap<crtc::Handle, SurfaceData>,
    non_desktop_connectors: Vec<(connector::Handle, crtc::Handle)>,
    active_leases: Vec<DrmLease>,
    gbm_device: GbmDevice<DrmDeviceFd>,
    gbm_allocator: GbmAllocator<DrmDeviceFd>,
    drm_device: DrmDevice,
    drm_scanner: DrmScanner,
    render_node: DrmNode,
    registration_token: RegistrationToken,
    swapchain: Swapchain<Box<dyn Allocator<Buffer=Dmabuf, Error=AnyError> + 'static>>,
    current_slot: Option<Slot<Dmabuf>>,
    last_rendered_slot: Option<Slot<Dmabuf>>,
}

#[derive(Debug, thiserror::Error)]
#[allow(dead_code)]
enum DeviceAddError {
    #[error("Failed to open device using libseat: {0}")]
    DeviceOpen(libseat::Error),
    #[error("Failed to initialize drm device: {0}")]
    DrmDevice(DrmError),
    #[error("Failed to initialize gbm device: {0}")]
    GbmDevice(std::io::Error),
    #[error("Failed to access drm node: {0}")]
    DrmNode(CreateDrmNodeError),
    #[error("Failed to add device to GpuManager: {0}")]
    AddNode(egl::Error),
}

impl ServerState<DrmBackend> {
    fn gpu_added(&mut self, node: DrmNode, path: &Path) -> Result<(), DeviceAddError> {
        // Try to open the device
        let fd = self
            .backend_data
            .session
            .open(
                path,
                OFlags::RDWR | OFlags::CLOEXEC | OFlags::NOCTTY | OFlags::NONBLOCK,
            )
            .map_err(DeviceAddError::DeviceOpen)?;

        let fd = DrmDeviceFd::new(unsafe { DeviceFd::from_raw_fd(fd.as_raw_fd()) });
        let (drm, notifier) = DrmDevice::new(fd.clone(), true).map_err(DeviceAddError::DrmDevice)?;

        let registration_token = self
            .loop_handle
            .insert_source(
                notifier,
                move |event, _metadata, data: &mut CalloopData<_>| match event {
                    DrmEvent::VBlank(crtc) => {
                        data.state.is_next_vblank_scheduled = false;
                        if let Some(surface) = data.state.backend_data.gpus.get_mut(&node).unwrap().surfaces.get_mut(&crtc) {
                            let _ = surface.compositor.frame_submitted();
                        }
                        if let Some(baton) = data.baton.take() {
                            data.state.flutter_engine().on_vsync(baton).unwrap();
                        }
                    }
                    DrmEvent::Error(error) => {
                        error!("{:?}", error);
                    }
                },
            )
            .unwrap();

        let gbm_device = GbmDevice::new(fd.clone()).map_err(DeviceAddError::GbmDevice)?;
        let egl_display = EGLDisplay::new(gbm_device.clone()).expect("Failed to create EGLDisplay");
        let render_node = EGLDevice::device_for_display(&egl_display)
            .ok()
            .and_then(|x| x.try_get_render_node().ok().flatten())
            .unwrap_or(node);

        let gbm_allocator = GbmAllocator::new(
            gbm_device.clone(),
            GbmBufferFlags::RENDERING | GbmBufferFlags::SCANOUT,
        );

        let gles_renderer = unsafe { GlesRenderer::new(EGLContext::new(&egl_display).unwrap()) }.unwrap();

        let swapchain = {
            let dmabuf_allocator: Box<dyn Allocator<Buffer=Dmabuf, Error=AnyError>> = {
                let gbm_allocator = GbmAllocator::new(gbm_device.clone(), GbmBufferFlags::RENDERING);
                Box::new(DmabufAllocator(gbm_allocator))
            };
            let modifiers = gles_renderer.egl_context().dmabuf_texture_formats().iter().map(|format| format.modifier).collect::<Vec<_>>();
            Swapchain::new(dmabuf_allocator, 0, 0, Fourcc::Argb8888, modifiers)
        };

        self.gles_renderer = Some(gles_renderer);
        self.gl = Some(Gles2::load_with(|s| unsafe { egl::get_proc_address(s) } as *const _));

        self.backend_data.gpus.insert(
            node,
            GpuData {
                registration_token,
                gbm_device,
                gbm_allocator,
                drm_device: drm,
                drm_scanner: DrmScanner::new(),
                non_desktop_connectors: Vec::new(),
                render_node,
                surfaces: HashMap::new(),
                active_leases: Vec::new(),
                swapchain,
                current_slot: None,
                last_rendered_slot: None,
            },
        );

        Ok(())
    }

    fn connector_connected(&mut self, node: DrmNode, connector: connector::Info, crtc: crtc::Handle) {
        let device = if let Some(device) = self.backend_data.gpus.get_mut(&node) {
            device
        } else {
            return;
        };

        let output_name = format!("{}-{}", connector.interface().as_str(), connector.interface_id());
        info!(?crtc, "Trying to setup connector {}", output_name,);

        let non_desktop = device
            .drm_device
            .get_properties(connector.handle())
            .ok()
            .and_then(|props| {
                let (info, value) = props
                    .into_iter()
                    .filter_map(|(handle, value)| {
                        let info = device.drm_device.get_property(handle).ok()?;
                        Some((info, value))
                    })
                    .find(|(info, _)| info.name().to_str() == Ok("non-desktop"))?;

                info.value_type().convert_value(value).as_boolean()
            })
            .unwrap_or(false);

        let (make, model) = EdidInfo::for_connector(&device.drm_device, connector.handle())
            .map(|info| (info.manufacturer, info.model))
            .unwrap_or_else(|| ("Unknown".into(), "Unknown".into()));

        if non_desktop {
            info!("Connector {} is non-desktop, setting up for leasing", output_name);
            device.non_desktop_connectors.push((connector.handle(), crtc));
            return;
        }

        let mode_id = connector
            .modes()
            .iter()
            .position(|mode| mode.mode_type().contains(ModeTypeFlags::PREFERRED))
            .unwrap_or(0);

        let drm_mode = connector.modes()[mode_id];
        let wl_mode = Mode::from(drm_mode);

        let surface = match device.drm_device.create_surface(crtc, drm_mode, &[connector.handle()]) {
            Ok(surface) => surface,
            Err(err) => {
                warn!("Failed to create drm surface: {}", err);
                return;
            }
        };

        let (phys_w, phys_h) = connector.size().unwrap_or((0, 0));
        let output = Output::new(
            output_name,
            PhysicalProperties {
                size: (phys_w as i32, phys_h as i32).into(),
                subpixel: Subpixel::Unknown,
                make,
                model,
            },
        );
        let global = output.create_global::<ServerState<DrmBackend>>(&self.display_handle);

        output.set_preferred(wl_mode);
        output.change_current_state(Some(wl_mode), None, None, Some((0, 0).into()));

        let color_formats = if std::env::var("ANVIL_DISABLE_10BIT").is_ok() {
            SUPPORTED_FORMATS_8BIT_ONLY
        } else {
            SUPPORTED_FORMATS
        };

        let render_formats = self.gles_renderer.as_ref().unwrap().egl_context().dmabuf_render_formats().clone();

        let driver = match device.drm_device.get_driver() {
            Ok(driver) => driver,
            Err(err) => {
                warn!("Failed to query drm driver: {}", err);
                return;
            }
        };

        let mut planes = surface.planes().clone();

        // Using an overlay plane on a nvidia card breaks
        if driver.name().to_string_lossy().to_lowercase().contains("nvidia")
            || driver
            .description()
            .to_string_lossy()
            .to_lowercase()
            .contains("nvidia")
        {
            planes.overlay = vec![];
        }

        let compositor = match DrmCompositor::new(
            &output,
            surface,
            Some(planes),
            device.gbm_allocator.clone(),
            device.gbm_device.clone(),
            color_formats,
            render_formats,
            device.drm_device.cursor_size(),
            Some(device.gbm_device.clone()),
        ) {
            Ok(compositor) => compositor,
            Err(err) => {
                warn!("Failed to create drm compositor: {}", err);
                return;
            }
        };

        let mut surface = SurfaceData {
            dh: self.display_handle.clone(),
            device_id: node,
            render_node: device.render_node,
            global: Some(global),
            compositor,
        };

        // Start first frame with a solid color. This will trigger the first VBLank event.
        surface
            .compositor
            .render_frame::<_, TextureRenderElement<_>, GlesTexture>(
                self.gles_renderer.as_mut().unwrap(),
                &[],
                [0.0, 0.0, 0.0, 0.0])
            .unwrap();
        surface.compositor.queue_frame(None).unwrap();
        surface.compositor.reset_buffers();

        device.surfaces.insert(crtc, surface);

        device.swapchain.resize(wl_mode.size.w as u32, wl_mode.size.h as u32);
        self.flutter_engine().send_window_metrics((wl_mode.size.w as u32, wl_mode.size.h as u32).into()).unwrap();
    }

    fn connector_disconnected(&mut self, node: DrmNode, connector: connector::Info, crtc: crtc::Handle) {
        let device = if let Some(device) = self.backend_data.gpus.get_mut(&node) {
            device
        } else {
            return;
        };

        if let Some(pos) = device
            .non_desktop_connectors
            .iter()
            .position(|(handle, _)| *handle == connector.handle())
        {
            let _ = device.non_desktop_connectors.remove(pos);
        } else {
            device.surfaces.remove(&crtc);
        }
    }

    fn device_changed(&mut self, node: DrmNode) {
        let device = if let Some(device) = self.backend_data.gpus.get_mut(&node) {
            device
        } else {
            return;
        };

        for event in device.drm_scanner.scan_connectors(&device.drm_device) {
            match event {
                DrmScanEvent::Connected { connector, crtc: Some(crtc) } => self.connector_connected(node, connector, crtc),
                DrmScanEvent::Disconnected { connector, crtc: Some(crtc) } => self.connector_disconnected(node, connector, crtc),
                _ => {}
            }
        }
    }
}

#[allow(dead_code)]
struct SurfaceData {
    dh: DisplayHandle,
    device_id: DrmNode,
    render_node: DrmNode,
    global: Option<GlobalId>,
    compositor: GbmDrmCompositor,
}

pub type GbmDrmCompositor = DrmCompositor<
    GbmAllocator<DrmDeviceFd>,
    GbmDevice<DrmDeviceFd>,
    Option<OutputPresentationFeedback>,
    DrmDeviceFd,
>;
