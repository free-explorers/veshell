use smithay::backend::{
    allocator::dmabuf::Dmabuf, renderer::gles::GlesRenderer, session::libseat::LibSeatSession,
};

pub mod drm_backend;
pub mod render;
pub mod winit;
pub mod x11_client;
pub trait Backend {
    const HAS_RELATIVE_MOTION: bool = false;

    fn seat_name(&self) -> String;

    fn get_session(&self) -> LibSeatSession;

    fn with_primary_renderer_mut<T>(&mut self, f: impl FnOnce(&mut GlesRenderer) -> T)
        -> Option<T>;

    fn get_buffer_for_view(&mut self, view_id: i64) -> Option<Dmabuf>;
}
