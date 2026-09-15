use smithay::backend::renderer::element::solid;
use std::sync::Mutex;

use crate::{
    backend::render::fractionnal_texture::{
        FractionnalTextureBuffer, FractionnalTextureRenderElement,
    },
    capture::CaptureSession,
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
                Id, Kind, RenderElement,
            },
            Color32F, ImportAll, ImportDma, ImportMem, Renderer, RendererSuper,
        },
    },
    input::pointer::CursorImageStatus,
    output::Output,
    reexports::wayland_server::protocol::wl_surface::WlSurface,
    utils::{Logical, Monotonic, Physical, Point, Rectangle, Scale, Time, Transform},
};

pub static CLEAR_COLOR: [f32; 4] = [0.8, 0.8, 0.9, 1.0];
mod fractionnal_memory;
mod fractionnal_texture;
smithay::backend::renderer::element::render_elements! {
    pub VeshellRenderElements<R> where
        R: ImportAll + ImportMem;
    Cursor=RelocateRenderElement<CursorRenderElement<R>>,
    Flutter=FractionnalTextureRenderElement<R::TextureId>,
    Surface=WaylandSurfaceRenderElement<R>,
    Solid=solid::SolidColorRenderElement
}

/// Half-transparent black used to dim everything outside the selection.
const SCRIM_COLOR: [f32; 4] = [0.0, 0.0, 0.0, 0.4];
/// Bright translucent white used for the selection outline and crosshair.
const SELECTION_COLOR: [f32; 4] = [1.0, 1.0, 1.0, 0.9];
/// Thickness of the selection outline and crosshair, in physical pixels.
const SELECTION_LINE_WIDTH: i32 = 2;
/// Half length of the crosshair arms, in physical pixels.
const CROSSHAIR_HALF_LENGTH: i32 = 16;

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
    capture_overlay: Option<&CaptureSession>,
) -> Vec<VeshellRenderElements<R>>
where
    R: Renderer + ImportAll + ImportMem + ImportDma,
    <R as RendererSuper>::TextureId: Send + Clone + 'static,
    <R as RendererSuper>::Error:,
    VeshellRenderElements<R>: RenderElement<R>,
{
    let dmabuf = slot.export().unwrap();
    get_render_elements_from_dmabuf(
        renderer,
        output,
        &dmabuf,
        output_geometry,
        now,
        cursor_image_status,
        cursor_state,
        cursor_location,
        is_surface_under_pointer,
        flip_flutter_texture,
        surfaces_in_gaming_mode,
        capture_overlay,
    )
}

/// The desktop frame without the pointer: Flutter texture plus surfaces
/// rendered through the game-mode fallback. Used both by the frozen screen
/// render (real cursor drawn by the caller) and by the capture readback
/// (no cursor at all).
pub fn get_frame_elements_from_dmabuf<R>(
    renderer: &mut R,
    output: &Output,
    dmabuf: &Dmabuf,
    output_geometry: Rectangle<f64, smithay::utils::Logical>,
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

    for surface in surfaces_in_gaming_mode {
        elements.extend(get_surface_elements(renderer, surface));
    }

    let flutter_texture_result = renderer.import_dmabuf(dmabuf, None);
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

    elements
}

/// The selected area drawn natively while a screenshot session runs.
/// The first element is topmost: crosshair, then outline, then the dimming
/// scrim; the frozen desktop sits underneath.
pub fn get_capture_overlay_elements<R>(
    output_geometry: Rectangle<f64, Logical>,
    scale: f64,
    session: &CaptureSession,
) -> Vec<VeshellRenderElements<R>>
where
    R: Renderer + ImportAll + ImportMem,
    <R as RendererSuper>::TextureId: Send + Clone + 'static,
    <R as RendererSuper>::Error:,
    VeshellRenderElements<R>: RenderElement<R>,
{
    // Converts a global logical rectangle to a physical one relative to the
    // output's own top-left corner, as expected by the render output.
    let to_local_physical = |rect: Rectangle<f64, Logical>| -> Rectangle<i32, Physical> {
        let left = ((rect.loc.x - output_geometry.loc.x) * scale) as i32;
        let top = ((rect.loc.y - output_geometry.loc.y) * scale) as i32;
        let width = (rect.size.w * scale).ceil() as i32;
        let height = (rect.size.h * scale).ceil() as i32;
        Rectangle::new((left, top).into(), (width, height).into())
    };
    let mut elements: Vec<VeshellRenderElements<R>> = Vec::new();
    let mut push_solid = |region: Rectangle<i32, Physical>, color: [f32; 4]| {
        elements.push(VeshellRenderElements::Solid(
            solid::SolidColorRenderElement::new(
                Id::new(),
                region,
                1,
                Color32F::new(color[0], color[1], color[2], color[3]),
                Kind::Unspecified,
            ),
        ));
    };

    let output_size_physical =
        to_local_physical(Rectangle::new(output_geometry.loc, output_geometry.size));

    // Native crosshair at the live pointer position, topmost.
    let position = to_local_physical(Rectangle::new(session.current, (0., 0.).into()));
    let (width, half) = (SELECTION_LINE_WIDTH, CROSSHAIR_HALF_LENGTH);
    let center_x = position.loc.x + width / 2;
    let center_y = position.loc.y + width / 2;
    push_solid(
        Rectangle::new(
            (center_x - half, center_y - width / 2).into(),
            (half * 2, width).into(),
        ),
        SELECTION_COLOR,
    );
    push_solid(
        Rectangle::new(
            (center_x - width / 2, center_y - half).into(),
            (width, half * 2).into(),
        ),
        SELECTION_COLOR,
    );

    // Selection outline (front) and scrim over the frozen desktop (back):
    // elements are painted deepest-first by the damage tracker, so the
    // last pushed element is the furthest away.
    match session.selection() {
        Some(selection) => {
            let hole = to_local_physical(selection);
            for region in scrim_regions(output_size_physical, hole) {
                push_solid(region, SCRIM_COLOR);
            }

            // Outline stroke: four physical rects around the selection.
            let stroke = SELECTION_LINE_WIDTH;
            let x = hole.loc.x;
            let y = hole.loc.y;
            let (width, height) = (hole.size.w, hole.size.h);
            for region in [
                Rectangle::new(
                    (x - stroke, y - stroke).into(),
                    (width + stroke * 2, stroke).into(),
                ),
                Rectangle::new(
                    (x - stroke, y + height).into(),
                    (width + stroke * 2, stroke).into(),
                ),
                Rectangle::new((x - stroke, y).into(), (stroke, height).into()),
                Rectangle::new((x + width, y).into(), (stroke, height).into()),
            ] {
                push_solid(region, SELECTION_COLOR);
            }
        }
        None => {
            push_solid(output_size_physical, SCRIM_COLOR);
        }
    }

    elements
}

/// The rectangles covering `full` but not `hole` (left, right, top, bottom).
fn scrim_regions(
    full: Rectangle<i32, Physical>,
    hole: Rectangle<i32, Physical>,
) -> Vec<Rectangle<i32, Physical>> {
    let full_left = full.loc.x;
    let full_right = full_left + full.size.w;
    let full_top = full.loc.y;
    let full_bottom = full_top + full.size.h;
    let hole_left = hole.loc.x.max(full_left);
    let hole_right = (hole.loc.x + hole.size.w).min(full_right);
    let hole_top = hole.loc.y.max(full_top);
    let hole_bottom = (hole.loc.y + hole.size.h).min(full_bottom);

    vec![
        // Left strip
        Rectangle::new(
            (full_left, full_top).into(),
            ((hole_left - full_left).max(0), full.size.h).into(),
        ),
        // Right strip
        Rectangle::new(
            (hole_right, full_top).into(),
            ((full_right - hole_right).max(0), full.size.h).into(),
        ),
        // Top strip above the hole
        Rectangle::new(
            (hole_left, full_top).into(),
            (
                (hole_right - hole_left).max(0),
                (hole_top - full_top).max(0),
            )
                .into(),
        ),
        // Bottom strip below the hole
        Rectangle::new(
            (hole_left, hole_bottom).into(),
            (
                (hole_right - hole_left).max(0),
                (full_bottom - hole_bottom).max(0),
            )
                .into(),
        ),
    ]
    .into_iter()
    .filter(|region| region.size.w > 0 && region.size.h > 0)
    .collect()
}

pub fn get_render_elements_from_dmabuf<R>(
    renderer: &mut R,
    output: &Output,
    dmabuf: &Dmabuf,
    output_geometry: Rectangle<f64, smithay::utils::Logical>,
    now: Time<Monotonic>,
    cursor_image_status: &Mutex<CursorImageStatus>,
    cursor_state: &Mutex<CursorStateInner>,
    cursor_location: Point<f64, Logical>,
    is_surface_under_pointer: bool,
    flip_flutter_texture: bool,
    surfaces_in_gaming_mode: Vec<&WlSurface>,
    capture_overlay: Option<&CaptureSession>,
) -> Vec<VeshellRenderElements<R>>
where
    R: Renderer + ImportAll + ImportMem + ImportDma,
    <R as RendererSuper>::TextureId: Send + Clone + 'static,
    <R as RendererSuper>::Error:,
    VeshellRenderElements<R>: RenderElement<R>,
{
    let scale = output.current_scale();
    let mut elements: Vec<VeshellRenderElements<R>> = Vec::new();

    // While a screenshot session freezes the desktop, the real cursor is
    // replaced by the native crosshair + selection overlay. The client may
    // provide its own cursor imagery; it must not appear during the drag.
    elements.extend(
        capture_overlay
            .map(|capture| {
                get_capture_overlay_elements(output_geometry, scale.fractional_scale(), capture)
            })
            .unwrap_or_default(),
    );

    if capture_overlay.is_none() && output_geometry.contains(cursor_location) {
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

    let mut frame_elements = get_frame_elements_from_dmabuf(
        renderer,
        output,
        dmabuf,
        output_geometry,
        flip_flutter_texture,
        surfaces_in_gaming_mode,
    );
    elements.append(&mut frame_elements);

    elements
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
