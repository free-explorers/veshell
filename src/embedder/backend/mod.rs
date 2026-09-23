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
pub mod x11_client;
pub trait Backend {
    const HAS_RELATIVE_MOTION: bool = false;
    const FLIP_FLUTTER_TEXTURE: bool = false;
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
