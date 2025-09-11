use std::sync::Mutex;

use crate::{
    backend::render::fractionnal_texture::{
        FractionnalTextureBuffer, FractionnalTextureRenderElement,
    },
    cursor::{draw_cursor, CursorRenderElement, CursorStateInner},
    meta_window_state::meta_window::MetaWindow,
};

use smithay::{
    backend::{
        allocator::{
            dmabuf::{AsDmabuf, Dmabuf},
            Slot,
        },
        renderer::{
            element::{
                surface::{render_elements_from_surface_tree, WaylandSurfaceRenderElement},
                texture::{TextureBuffer, TextureRenderElement},
                utils::{Relocate, RelocateRenderElement},
                Kind, RenderElement,
            },
            ImportAll, ImportDma, ImportMem, Renderer, RendererSuper,
        },
    },
    input::pointer::CursorImageStatus,
    output::Output,
    reexports::wayland_server::protocol::wl_surface::WlSurface,
    utils::{Logical, Monotonic, Point, Rectangle, Time, Transform},
};

pub static CLEAR_COLOR: [f32; 4] = [0.8, 0.8, 0.9, 1.0];
mod fractionnal_memory;
mod fractionnal_texture;
smithay::backend::renderer::element::render_elements! {
    pub VeshellRenderElements<R> where
        R: ImportAll + ImportMem;
    Cursor=RelocateRenderElement<CursorRenderElement<R>>,
    Flutter=FractionnalTextureRenderElement<R::TextureId>,
    Surface=WaylandSurfaceRenderElement<R>
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
    flip_flutter_texture: bool,
    surfaces_in_gaming_mode: Vec<&WlSurface>,
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
            scale,
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

    for surface in surfaces_in_gaming_mode {
        elements.extend(get_surface_elements(renderer, surface));
    }

    let flutter_texture_result = renderer.import_dmabuf(&slot.export().unwrap(), None);
    let transform = if flip_flutter_texture {
        Transform::Flipped180
    } else {
        Transform::Normal
    };
    if flutter_texture_result.is_ok() {
        let flutter_texture = flutter_texture_result.unwrap();
        let flutter_texture_buffer = FractionnalTextureBuffer::from_texture(
            renderer,
            flutter_texture,
            scale.fractional_scale(),
            transform,
            Vec::new(),
        );
        let flutter_texture_element = FractionnalTextureRenderElement::from_texture_buffer(
            flutter_texture_buffer,
            Point::from((0.0, 0.0)),
            1.,
            Some(Rectangle {
                loc: (0., 0.).into(),
                size: output_geometry.size,
            }),
            None,
            Kind::Unspecified,
        );
        elements.push(VeshellRenderElements::Flutter(flutter_texture_element));
    }

    return elements;
}

pub fn get_surface_elements<R>(
    renderer: &mut R,
    surface: &WlSurface,
) -> Vec<VeshellRenderElements<R>>
where
    R: Renderer + ImportAll + ImportMem + ImportDma,
    <R as RendererSuper>::TextureId: Send + Clone + 'static,
    <R as RendererSuper>::Error:,
    VeshellRenderElements<R>: RenderElement<R>,
{
    render_elements_from_surface_tree(renderer, surface, (0, 0), 1.0, 1.0, Kind::Unspecified)
}
