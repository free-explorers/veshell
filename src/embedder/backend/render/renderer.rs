use smithay::backend::renderer::gles::{GlesError, GlesFrame, GlesRenderer};
use smithay::backend::renderer::{ImportAll, ImportDma, ImportMem, Renderer};

/// A renderer that composites outputs.
///
/// The Flutter frame always lives on the render GPU, the one Flutter renders
/// on. An output of another GPU is composited by a multi-GPU renderer: it
/// draws on the render GPU, then hands the result to the output's GPU. The
/// Flutter texture is therefore imported and drawn through the render GPU's
/// own GLES renderer and frame, which this trait exposes; client buffers go
/// through the renderer itself, which imports them wherever it renders.
pub trait VeshellRenderer: Renderer + ImportAll + ImportMem + ImportDma {
    /// The GLES renderer of the render GPU.
    fn as_gles_renderer(&mut self) -> &mut GlesRenderer;

    /// The render GPU's GLES frame inside one of this renderer's frames.
    fn as_gles_frame<'a, 'frame, 'buffer>(
        frame: &'a mut Self::Frame<'frame, 'buffer>,
    ) -> &'a mut GlesFrame<'frame, 'buffer>
    where
        'buffer: 'frame,
        Self: 'frame;

    /// A GLES error, as an error of this renderer.
    fn gles_error(error: GlesError) -> Self::Error;
}

impl VeshellRenderer for GlesRenderer {
    fn as_gles_renderer(&mut self) -> &mut GlesRenderer {
        self
    }

    fn as_gles_frame<'a, 'frame, 'buffer>(
        frame: &'a mut GlesFrame<'frame, 'buffer>,
    ) -> &'a mut GlesFrame<'frame, 'buffer>
    where
        'buffer: 'frame,
    {
        frame
    }

    fn gles_error(error: GlesError) -> GlesError {
        error
    }
}
