use std::sync::Mutex;

use crate::cursor::{draw_cursor, CursorRenderElement, CursorStateInner};

use smithay::{
    backend::{
        allocator::{
            dmabuf::{AsDmabuf, Dmabuf},
            Slot,
        },
        renderer::{
            element::{
                texture::{TextureBuffer, TextureRenderElement},
                utils::{Relocate, RelocateRenderElement},
                Kind, RenderElement,
            },
            ImportAll, ImportDma, ImportMem, Renderer, RendererSuper,
        },
    },
    input::pointer::CursorImageStatus,
    output::Output,
    utils::{Logical, Monotonic, Point, Rectangle, Time, Transform},
};

pub static CLEAR_COLOR: [f32; 4] = [0.8, 0.8, 0.9, 1.0];

smithay::backend::renderer::element::render_elements! {
    pub VeshellRenderElements<R> where
        R: ImportAll + ImportMem;
    Cursor=RelocateRenderElement<CursorRenderElement<R>>,
    Flutter=TextureRenderElement<R::TextureId>,
}

pub fn get_render_elements<R>(
    renderer: &mut R,
    output: &Output,
    slot: &Slot<Dmabuf>,
    output_geometry: Rectangle<f64, smithay::utils::Logical>,
    now: Time<Monotonic>,
    cursor_image_status: &Mutex<CursorImageStatus>,
    cursor_state: &Mutex<CursorStateInner>,
    cursor_location: Point<f64, Logical>,
    is_surface_under_pointer: bool,
) -> Vec<VeshellRenderElements<R>>
where
    R: Renderer + ImportAll + ImportMem + ImportDma,
    <R as RendererSuper>::TextureId: Send + Clone + 'static,
    <R as RendererSuper>::Error:,
    VeshellRenderElements<R>: RenderElement<R>,
{
    let scale = output.current_scale();
    let mut elements: Vec<VeshellRenderElements<R>> = Vec::new();

    // check if the cursor is inside the output geometry
    if output_geometry.contains(cursor_location) {
        let cursor_element = draw_cursor(
            renderer,
            cursor_image_status,
            cursor_state,
            scale.fractional_scale().into(),
            now,
            cursor_location - output_geometry.loc,
            is_surface_under_pointer,
        );

        let cursor_elements: Vec<VeshellRenderElements<R>> = cursor_element
            .into_iter()
            .map(|(elem, hotspot)| {
                VeshellRenderElements::Cursor(RelocateRenderElement::from_element(
                    elem,
                    Point::from((-hotspot.x, -hotspot.y)),
                    Relocate::Relative,
                ))
            })
            .collect();

        elements.extend(cursor_elements);
    }

    let flutter_texture_result = renderer.import_dmabuf(&slot.export().unwrap(), None);
    if flutter_texture_result.is_ok() {
        let flutter_texture = flutter_texture_result.unwrap();
        let flutter_texture_buffer = TextureBuffer::from_texture(
            renderer,
            flutter_texture,
            scale.integer_scale(),
            Transform::Flipped180,
            None,
        );
        let flutter_texture_element = TextureRenderElement::from_texture_buffer(
            Point::from((0.0, 0.0)),
            &flutter_texture_buffer,
            None,
            // TODO: I don't know why it has to be like this instead of just `geometry`.
            Some(Rectangle::new(
                (
                    output_geometry.loc.x,
                    output_geometry.size.h - output_geometry.loc.y,
                )
                    .into(),
                output_geometry.size,
            )),
            None,
            Kind::Unspecified,
        );
        elements.push(VeshellRenderElements::Flutter(flutter_texture_element));
    }

    return elements;
}
