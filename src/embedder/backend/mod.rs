use std::os::fd::AsFd;
use std::rc::Rc;

use smithay::backend::{
    allocator::{
        dmabuf::{AnyError, Dmabuf, DmabufAllocator},
        gbm::{GbmAllocator, GbmBufferFlags, GbmDevice},
        Allocator, Fourcc, Swapchain,
    },
    renderer::gles::GlesRenderer,
    session::libseat::LibSeatSession,
};
use smithay::reexports::gbm::Modifier;

/// Allocates capture-owned dmabufs the primary renderer can render into and
/// a PipeWire consumer can import. Implemented by the backend's GBM device;
/// `None` from [`Backend::capture_dmabuf_setup`] keeps the shared-memory
/// producer path.
pub trait CaptureDmabufAllocator {
    fn allocate(
        &self,
        width: u32,
        height: u32,
        fourcc: Fourcc,
        modifiers: &[Modifier],
    ) -> Result<Dmabuf, String>;
}

impl<A: AsFd + Clone + 'static> CaptureDmabufAllocator for GbmDevice<A> {
    fn allocate(
        &self,
        width: u32,
        height: u32,
        fourcc: Fourcc,
        modifiers: &[Modifier],
    ) -> Result<Dmabuf, String> {
        let mut allocator =
            DmabufAllocator(GbmAllocator::new(self.clone(), GbmBufferFlags::RENDERING));
        allocator
            .create_buffer(width, height, fourcc, modifiers)
            .map_err(|error| format!("{error:?}"))
    }
}

/// Everything the PipeWire producer needs to offer and allocate dmabufs:
/// the allocator plus the renderer-supported `(fourcc, modifier)` list.
#[derive(Clone)]
pub struct CaptureDmabufSetup {
    pub allocator: Rc<dyn CaptureDmabufAllocator>,
    pub formats: Vec<(Fourcc, Modifier)>,
}

pub mod drm_backend;
pub mod render;
pub mod winit;
pub trait Backend {
    const HAS_RELATIVE_MOTION: bool = false;
    /// Whether the compositor flips the Flutter texture vertically when it
    /// imports it.
    ///
    /// Flutter renders with a bottom-left origin, so its texture is upside
    /// down for the compositor. The engine-wide `surface_transformation`
    /// callback cannot express a per-view correction (it receives no view
    /// identifier; see `flutter_engine::callbacks::surface_transformation`),
    /// so backends correct the orientation here instead. This applies once per
    /// view and per render target, and is safe for multi-output setups.
    const FLIP_FLUTTER_TEXTURE: bool = false;
    /// Whether the backend can power outputs down at the KMS level when the
    /// screensaver reaches full dim. Backends without KMS access (nested)
    /// keep rendering the black overlay instead.
    const CAN_BLANK: bool = false;
    /// Whether the compositor drives the panel backlight directly.
    ///
    /// Only the real DRM session does: the nested backend shares the host's
    /// panel and must never dim it behind the host compositor's back.
    const CONTROLS_BACKLIGHT: bool = false;
    /// Only the real seat session (DRM) owns the portal backend name; a
    /// nested or non-session run must not answer portal requests on a
    /// foreign bus.
    const RUNS_PORTAL_BACKEND: bool = false;
    /// Whether this run owns `org.freedesktop.Notifications`.
    ///
    /// The compositor serves the freedesktop notifications interface and
    /// forwards accepted calls to the shell; the Dart server is gone. Like the
    /// portal backend, only the real seat session owns the name, so a nested or
    /// non-session run does not contend for it on a foreign bus.
    const RUNS_NOTIFICATION_SERVER: bool = false;
    /// Whether the backend applies the user-facing monitor transform as an
    /// output transform. The nested backend pins a `Flipped180` correction, so
    /// it must not have it overwritten by the (normal by default) setting.
    const SUPPORTS_OUTPUT_TRANSFORM: bool = false;

    fn seat_name(&self) -> String;

    fn get_session(&self) -> LibSeatSession;

    fn with_primary_renderer_mut<T>(&mut self, f: impl FnOnce(&mut GlesRenderer) -> T)
        -> Option<T>;

    fn new_swapchain(
        &mut self,
        width: u32,
        height: u32,
    ) -> Swapchain<Box<dyn Allocator<Buffer = Dmabuf, Error = AnyError> + 'static>>;

    /// The dmabuf allocator and the renderer-supported `(fourcc, modifier)`
    /// list for the PipeWire producer, or `None` when the backend cannot
    /// render into and export dmabufs (the producer then stays on shared
    /// memory).
    fn capture_dmabuf_setup(&mut self) -> Option<CaptureDmabufSetup>;
}
