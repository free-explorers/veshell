use smithay::{
    backend::{
        allocator::{
            dmabuf::{AnyError, Dmabuf},
            Allocator, Fourcc, Swapchain,
        },
        renderer::{gles::GlesRenderer, Bind},
        session::libseat::LibSeatSession,
    },
    reexports::gbm::{Format, Modifier},
};

pub mod drm_backend;
pub mod render;
// pub mod winit;
pub mod x11_client;
pub trait Backend {
    const HAS_RELATIVE_MOTION: bool = false;

    fn seat_name(&self) -> String;

    fn get_session(&self) -> LibSeatSession;

    fn with_primary_renderer_mut<T>(&mut self, f: impl FnOnce(&mut GlesRenderer) -> T)
        -> Option<T>;

    fn new_swapchain(
        &mut self,
        width: u32,
        height: u32,
        fourcc: Fourcc,
    ) -> Swapchain<Box<dyn Allocator<Buffer = Dmabuf, Error = AnyError> + 'static>>;
}

fn filtered_modifiers(renderer: &GlesRenderer, fourcc: Fourcc) -> Vec<Modifier> {
    Bind::<Dmabuf>::supported_formats(renderer)
        .unwrap()
        .iter()
        .filter(|format| format.code == fourcc)
        .map(|format| format.modifier)
        .collect()
}
