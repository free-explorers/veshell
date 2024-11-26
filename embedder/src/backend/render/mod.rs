use std::sync::Mutex;

use crate::{
    cursor::{draw_cursor, CursorRenderElement, CursorStateInner},
    state::State,
};

use smithay::{
    backend::{
        allocator::{
            dmabuf::{AsDmabuf, Dmabuf},
            Slot,
        },
        drm::DrmNode,
        renderer::{
            buffer_dimensions,
            damage::{Error as RenderError, OutputDamageTracker, RenderOutputResult},
            element::{
                surface::{render_elements_from_surface_tree, WaylandSurfaceRenderElement},
                texture::{TextureBuffer, TextureRenderElement},
                utils::{CropRenderElement, Relocate, RelocateRenderElement},
                AsRenderElements, Element, Id, Kind, RenderElement,
            },
            gles::{
                element::PixelShaderElement, GlesError, GlesPixelProgram, GlesRenderer, Uniform,
                UniformName, UniformType,
            },
            multigpu::{Error as MultiError, MultiFrame, MultiRenderer},
            sync::SyncPoint,
            Bind, Blit, Color32F, ExportMem, ImportAll, ImportDma, ImportMem, Offscreen, Renderer,
            Texture, TextureFilter,
        },
    },
    input::pointer::CursorImageStatus,
    output::{Output, OutputNoMode},
    utils::{IsAlive, Logical, Monotonic, Point, Rectangle, Scale, Time, Transform},
    wayland::{
        dmabuf::get_dmabuf,
        session_lock::LockSurface,
        shm::{shm_format_to_fourcc, with_buffer_contents},
    },
};

use super::Backend;

smithay::backend::renderer::element::render_elements! {
    pub VeshellRenderElements<=GlesRenderer>;
    Cursor=RelocateRenderElement<CursorRenderElement>,
    Flutter=TextureRenderElement<<GlesRenderer as Renderer>::TextureId>,
}

pub fn get_render_elements(
    renderer: &mut GlesRenderer,
    output: &Output,
    slot: &Slot<Dmabuf>,
    geometry: Rectangle<f64, smithay::utils::Logical>,
    now: Time<Monotonic>,
    cursor_image_status: &Mutex<CursorImageStatus>,
    cursor_state: &Mutex<CursorStateInner>,
    location: Point<f64, Logical>,
    is_surface_under_pointer: bool,
) -> Vec<VeshellRenderElements> {
    let scale = output.current_scale();

    let flutter_texture = renderer
        .import_dmabuf(&slot.export().unwrap(), None)
        .unwrap();
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
        Some(Rectangle::from_loc_and_size(
            (geometry.loc.x, geometry.size.h - geometry.loc.y),
            geometry.size,
        )),
        None,
        Kind::Unspecified,
    );

    let cursor_element = draw_cursor(
        renderer,
        cursor_image_status,
        cursor_state,
        scale.fractional_scale().into(),
        now,
        location,
        is_surface_under_pointer,
    );

    let mut elements: Vec<VeshellRenderElements> = Vec::new();
    let cursor_elements: Vec<VeshellRenderElements> = cursor_element
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
    elements.push(VeshellRenderElements::Flutter(flutter_texture_element));

    return elements;
}
