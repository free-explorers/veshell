use smithay::backend::{
    allocator::{
        dmabuf::{AnyError, Dmabuf},
        Allocator, Swapchain,
    },
    renderer::gles::GlesRenderer,
    session::libseat::LibSeatSession,
};

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
    /// Only the real seat session (DRM) owns the portal backend name; a
    /// nested or non-session run must not answer portal requests on a
    /// foreign bus.
    const RUNS_PORTAL_BACKEND: bool = false;

    fn seat_name(&self) -> String;

    fn get_session(&self) -> LibSeatSession;

    fn with_primary_renderer_mut<T>(&mut self, f: impl FnOnce(&mut GlesRenderer) -> T)
        -> Option<T>;

    fn new_swapchain(
        &mut self,
        width: u32,
        height: u32,
    ) -> Swapchain<Box<dyn Allocator<Buffer = Dmabuf, Error = AnyError> + 'static>>;
}
