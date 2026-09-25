use smithay::backend::renderer::element::solid;
use std::cell::RefCell;
use std::collections::HashMap;
use std::sync::{LazyLock, Mutex, OnceLock};
use tracing::debug;

use crate::capture::{RECORDING_CHIP_HEIGHT, RECORDING_CHIP_WIDTH};
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
            Fourcc, Slot,
        },
        renderer::{
            element::{
                memory::{MemoryRenderBuffer, MemoryRenderBufferRenderElement},
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
    utils::{Buffer, Logical, Monotonic, Physical, Point, Rectangle, Scale, Size, Time, Transform},
};

pub static CLEAR_COLOR: [f32; 4] = [0.8, 0.8, 0.9, 1.0];
mod fractionnal_memory;
mod fractionnal_texture;
smithay::backend::renderer::element::render_elements! {
    pub VeshellRenderElements<R> where
        R: ImportAll + ImportMem;
    Memory=MemoryRenderBufferRenderElement<R>,
    Cursor=RelocateRenderElement<CursorRenderElement<R>>,
    Flutter=FractionnalTextureRenderElement<R::TextureId>,
    Surface=WaylandSurfaceRenderElement<R>,
    Solid=solid::SolidColorRenderElement
}

/// Half-transparent black used to dim everything outside the selection.
const SCRIM_COLOR: [f32; 4] = [0.0, 0.0, 0.0, 0.4];
/// Screensaver dim overlay: black at full coverage, alpha driven by idle.
const DIM_BASE_COLOR: [f32; 4] = [0.0, 0.0, 0.0, 0.9];
/// Element id for the screensaver dim overlay, stable across frames.
const ID_IDLE_DIM: u64 = 0x3000;
/// Bright translucent white used for the selection outline and crosshair.
const SELECTION_COLOR: [f32; 4] = [1.0, 1.0, 1.0, 0.9];
/// Thickness of the selection outline and crosshair, in physical pixels.
const SELECTION_LINE_WIDTH: i32 = 2;
/// Half length of the crosshair arms, in physical pixels.
const CROSSHAIR_HALF_LENGTH: i32 = 16;

// Stable element ids for the capture/recording overlay solids. The damage
// tracker keys elements by `Id`; a fresh `Id` every frame makes every
// element look new and repaints the whole output, so the constant solids
// (scrim, outline, crosshair) reuse one id per role. The ranges keep the
// two overlays from colliding if both are ever live.
const ID_SELECTION_CROSSHAIR: u64 = 0x1000;
const ID_SELECTION_SCRIM: u64 = 0x1100;
const ID_SELECTION_OUTLINE: u64 = 0x1200;
const ID_RECORDING_SCRIM: u64 = 0x2000;
const ID_RECORDING_OUTLINE: u64 = 0x2100;

/// Returns a stable [`Id`] for one overlay role, creating it on first use.
/// Cloning shares the same id, so the damage tracker sees an unchanged
/// element when its geometry is unchanged too.
fn stable_solid_id(key: u64) -> Id {
    thread_local! {
        static IDS: RefCell<HashMap<u64, Id>> = RefCell::new(HashMap::new());
    }
    IDS.with(|ids| ids.borrow_mut().entry(key).or_insert_with(Id::new).clone())
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
    idle_dim_alpha: f32,
    surfaces_in_gaming_mode: Vec<&WlSurface>,
    capture_overlay: Option<&CaptureSession>,
    recording_chip: Option<crate::capture::RecordingChipData>,
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
        idle_dim_alpha,
        surfaces_in_gaming_mode,
        capture_overlay,
        recording_chip,
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
    let mut push_solid = |id_key: u64, region: Rectangle<i32, Physical>, color: [f32; 4]| {
        elements.push(VeshellRenderElements::Solid(
            solid::SolidColorRenderElement::new(
                stable_solid_id(id_key),
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
        ID_SELECTION_CROSSHAIR,
        Rectangle::new(
            (center_x - half, center_y - width / 2).into(),
            (half * 2, width).into(),
        ),
        SELECTION_COLOR,
    );
    push_solid(
        ID_SELECTION_CROSSHAIR + 1,
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
            for (index, region) in scrim_regions(output_size_physical, hole)
                .into_iter()
                .enumerate()
            {
                push_solid(ID_SELECTION_SCRIM + index as u64, region, SCRIM_COLOR);
            }

            // Outline stroke: four physical rects around the selection.
            let stroke = SELECTION_LINE_WIDTH;
            let x = hole.loc.x;
            let y = hole.loc.y;
            let (width, height) = (hole.size.w, hole.size.h);
            for (index, region) in [
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
            ]
            .into_iter()
            .enumerate()
            {
                push_solid(ID_SELECTION_OUTLINE + index as u64, region, SELECTION_COLOR);
            }
        }
        None => {
            push_solid(ID_SELECTION_SCRIM, output_size_physical, SCRIM_COLOR);
        }
    }

    elements
}

/// Per-thread cache of the recording overlay's memory buffers. Caching the
/// buffers keeps their `Id` stable across frames, so a static scene only
/// re-imports the constant chip once and the counter when its displayed
/// second changes, instead of re-rasterizing and re-importing both every
/// present.
#[derive(Default)]
struct RecordingBuffers {
    /// The constant chip chrome, keyed by integer scale.
    chip: Option<(i32, MemoryRenderBuffer)>,
    /// Counter textures keyed by `(seconds, integer scale)`.
    counters: HashMap<(u64, i32), MemoryRenderBuffer>,
}

thread_local! {
    static RECORDING_BUFFERS: RefCell<RecordingBuffers> = RefCell::new(RecordingBuffers::default());
}

/// The counter runs at most to 99:59, so the per-second cache is bounded.
const RECORDING_COUNTER_CACHE_LIMIT: usize = 256;

fn recording_chip_buffer(
    chip: &crate::capture::RecordingChipData,
    scale: f64,
) -> MemoryRenderBuffer {
    let integer_scale = scale.round().max(1.0) as i32;
    RECORDING_BUFFERS.with(|cache| {
        let mut cache = cache.borrow_mut();
        if let Some((cached_scale, buffer)) = cache.chip.as_ref() {
            if *cached_scale == integer_scale {
                return buffer.clone();
            }
        }
        let (data, size) = recording_chip_bitmap(chip, scale);
        let buffer = MemoryRenderBuffer::from_slice(
            &data,
            Fourcc::Argb8888,
            size,
            integer_scale,
            Transform::Normal,
            None,
        );
        cache.chip = Some((integer_scale, buffer.clone()));
        buffer
    })
}

fn recording_counter_buffer(
    chip: &crate::capture::RecordingChipData,
    scale: f64,
) -> Option<MemoryRenderBuffer> {
    let integer_scale = scale.round().max(1.0) as i32;
    let seconds = chip.seconds.min(99 * 60 + 59);
    RECORDING_BUFFERS.with(|cache| {
        let mut cache = cache.borrow_mut();
        if let Some(buffer) = cache.counters.get(&(seconds, integer_scale)) {
            return Some(buffer.clone());
        }
        let (data, size) = recording_counter_bitmap(chip, scale)?;
        let buffer = MemoryRenderBuffer::from_slice(
            &data,
            Fourcc::Argb8888,
            size,
            integer_scale,
            Transform::Normal,
            None,
        );
        if cache.counters.len() >= RECORDING_COUNTER_CACHE_LIMIT {
            cache.counters.clear();
        }
        cache
            .counters
            .insert((seconds, integer_scale), buffer.clone());
        Some(buffer)
    })
}

/// The trusted recording indicator: the recorded rectangle's outline,
/// a dimmed desktop outside it, and a dark chip with a red dot plus the
/// elapsed time in the shell's own font, inside the rectangle's
/// bottom-right corner. Print is the only stop action; the capture
/// render path draws none of this, so recorded frames stay clean
/// (specification section 9).
pub fn get_recording_overlay_elements<R>(
    renderer: &mut R,
    output_geometry: Rectangle<f64, Logical>,
    scale: f64,
    chip: crate::capture::RecordingChipData,
) -> Vec<VeshellRenderElements<R>>
where
    R: Renderer + ImportAll + ImportMem,
    <R as RendererSuper>::TextureId: Send + Clone + 'static,
    <R as RendererSuper>::Error:,
    VeshellRenderElements<R>: RenderElement<R>,
{
    // Global logical -> local physical, like the selection overlay.
    let to_local_physical = |rect: Rectangle<f64, Logical>| -> Rectangle<i32, Physical> {
        let left = ((rect.loc.x - output_geometry.loc.x) * scale) as i32;
        let top = ((rect.loc.y - output_geometry.loc.y) * scale) as i32;
        Rectangle::new(
            (left, top).into(),
            (
                (rect.size.w * scale).ceil() as i32,
                (rect.size.h * scale).ceil() as i32,
            )
                .into(),
        )
    };

    let mut elements: Vec<VeshellRenderElements<R>> = Vec::new();
    // The recorded rectangle gets a visible outline and the desktop
    // outside it dims to the same scrim the selection uses. The first
    // element pushed is topmost, so the chip's digits come first and
    // the dimming scrim is pushed last, beneath all of the chip.
    let output_size_physical =
        to_local_physical(Rectangle::new(output_geometry.loc, output_geometry.size));
    let recorded = to_local_physical(chip.outline);
    let stroke = SELECTION_LINE_WIDTH;
    let x = recorded.loc.x;
    let y = recorded.loc.y;
    let (width, height) = (recorded.size.w, recorded.size.h);

    // mm:ss rasterized in the shell's own label font and pushed as a
    // texture so the counter reads like normal UI text.
    //
    // This renderer paints the first pushed element last, so the text
    // comes first and the background, outline, and dimming scrim pile
    // beneath it.
    let text_location = Point::<f64, Logical>::new(
        chip.chip.loc.x - output_geometry.loc.x,
        chip.chip.loc.y - output_geometry.loc.y,
    );
    // The counter rides the proven memory-buffer path the cursor uses:
    // MemoryRenderBuffer handles the import, orientation, and alpha for
    // memory slices itself. The buffer is cached per second, so a static
    // scene only re-imports the counter when the displayed time changes.
    let physical_location =
        Point::<f64, Physical>::new(text_location.x * scale, text_location.y * scale);
    if let Some(buffer) = recording_counter_buffer(&chip, scale) {
        match MemoryRenderBufferRenderElement::from_buffer(
            renderer,
            physical_location,
            &buffer,
            None,
            None,
            None,
            Kind::Unspecified,
        ) {
            Ok(element) => elements.push(VeshellRenderElements::Memory(element)),
            Err(error) => debug!(?error, "recording counter texture import failed"),
        }
    }

    // The chip's chrome (rounded translucent background + red circle)
    // is one memory texture beneath the text but above the outline and
    // the dimming scrim; this renderer paints the first pushed element
    // last. The chrome is constant for the whole recording.
    let chip_buffer = recording_chip_buffer(&chip, scale);
    if let Ok(element) = MemoryRenderBufferRenderElement::from_buffer(
        renderer,
        text_location.to_physical(scale),
        &chip_buffer,
        None,
        None,
        None,
        Kind::Unspecified,
    ) {
        elements.push(VeshellRenderElements::Memory(element));
    } else {
        debug!("recording chip texture import failed");
    }

    let mut push_solid = |id_key: u64, region: Rectangle<i32, Physical>, color: [f32; 4]| {
        elements.push(VeshellRenderElements::Solid(
            solid::SolidColorRenderElement::new(
                stable_solid_id(id_key),
                region,
                1,
                Color32F::new(color[0], color[1], color[2], color[3]),
                Kind::Unspecified,
            ),
        ));
    };

    // Outline and scrim sit beneath the chip within the overlay layer
    // (they are pushed later, and pushing later is pushed deeper). Their
    // geometry is fixed for the recording, so the stable ids keep them
    // out of the damage set on frames where only the counter changed.
    for (index, region) in [
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
    ]
    .into_iter()
    .enumerate()
    {
        push_solid(ID_RECORDING_OUTLINE + index as u64, region, SELECTION_COLOR);
    }
    for (index, region) in scrim_regions(output_size_physical, recorded)
        .into_iter()
        .enumerate()
    {
        push_solid(ID_RECORDING_SCRIM + index as u64, region, SCRIM_COLOR);
    }

    elements
}

/// Resolves (once, process-wide) the fontconfig substitution for the
/// shell's label font: Flutter asks fontconfig for the "Roboto" family,
/// and the recording counter uses the same resolution so its text matches
/// the shell's typography on any machine. The resolution shells out to
/// `fc-match` and reads a file, so it is pre-warmed at startup and never
/// runs on the render thread's first recorded frame.
fn recording_font() -> Option<&'static fontdue::Font> {
    static FONT: OnceLock<Option<fontdue::Font>> = OnceLock::new();
    FONT.get_or_init(|| {
        let file = std::process::Command::new("fc-match")
            .arg("--format=%{file}")
            .arg("Roboto")
            .output()
            .ok()?
            .stdout;
        let file = String::from_utf8(file).ok()?;
        fontdue::Font::from_bytes(
            std::fs::read(file.trim_end()).ok()?,
            fontdue::FontSettings::default(),
        )
        .ok()
    })
    .as_ref()
}

/// Pre-resolves the recording counter font. Call from startup so the
/// first recording never pays the `fc-match` subprocess on the render
/// thread; absence of fontconfig just disables the counter digits.
pub fn warm_recording_font() {
    let _ = recording_font();
}

/// Rasterizes the counter text with the fontconfig-resolved family
/// Flutter itself uses, onto a full-chip-sized canvas with the text
/// right-aligned and vertically centered inside it; returns
/// premultiplied BGRA with the coverage in every channel (a white pixel
/// whose alpha is the coverage), or None when the glyph lookup fails.
fn recording_counter_bitmap(
    chip: &crate::capture::RecordingChipData,
    scale: f64,
) -> Option<(Vec<u8>, Size<i32, Buffer>)> {
    let font = recording_font()?;

    let seconds = chip.seconds.min(99 * 60 + 59);
    let text = format!("{}:{:02}", seconds / 60, seconds % 60);

    // Everything is laid out on a canvas exactly the chip's size in
    // integer-scale pixels, so the element can be anchored at the chip
    // rectangle and the alignment cannot drift.
    let integer_scale = scale.round().max(1.0);
    let canvas_width = (RECORDING_CHIP_WIDTH * integer_scale).round() as i32;
    let canvas_height = (RECORDING_CHIP_HEIGHT * integer_scale).round() as i32;

    // Em size to make digit caps fill most of the chip; the digits share
    // identical metrics, so their common box is the layout reference and
    // everything else (the colon) is centered inside it.
    let px = (RECORDING_CHIP_HEIGHT * 0.72 * integer_scale) as f32;
    let (reference, _) = font.rasterize('0', px);
    let box_height = reference.height as i32;

    let mut placed = Vec::new();
    let mut pen_x = 0i32;
    for glyph in text.chars() {
        let (metrics, bitmap) = font.rasterize(glyph, px);
        let x = pen_x + metrics.xmin;
        let y = ((canvas_height - box_height) / 2) + (box_height - metrics.height as i32) / 2;
        placed.push((x, y, metrics.width as i32, metrics.height as i32, bitmap));
        pen_x += metrics.advance_width.round() as i32;
    }

    // Right-align the drawn text at the chip's right edge inset.
    const TEXT_RIGHT_INSET: f64 = 6.0;
    let text_width = pen_x;
    let text_start_x =
        canvas_width - (TEXT_RIGHT_INSET * integer_scale).round() as i32 - text_width;
    let shift_x = text_start_x;

    // Anti-aliased coverage is brightened with a wide gamma so the thin
    // glyph strokes of a small font render at full white against the
    // black chip instead of fading to gray.
    static WHITE_GAMMA: LazyLock<[u8; 256]> = LazyLock::new(|| {
        let mut table = [0u8; 256];
        for (coverage, boosted) in table.iter_mut().enumerate() {
            *boosted = ((coverage as f32 / 255.0).powf(0.45) * 255.0).round() as u8;
        }
        table
    });

    let mut data = vec![0u8; (canvas_width * canvas_height * 4) as usize];
    for (x, y, glyph_width, glyph_height, bitmap) in placed {
        for row in 0..glyph_height {
            for column in 0..glyph_width {
                let coverage = WHITE_GAMMA[bitmap[(row * glyph_width + column) as usize] as usize];
                let destination_x = shift_x + x + column;
                let destination_y = y + row;
                let destination = (destination_y * canvas_width + destination_x) as usize * 4;
                data[destination..destination + 4]
                    .copy_from_slice(&[coverage, coverage, coverage, coverage]);
            }
        }
    }
    Some((data, Size::from((canvas_width, canvas_height))))
}

/// Rasterizes the chip's chrome on a chip-sized canvas: a pill-shaped
/// translucent black background with the red recording circle on its
/// left, as premultiplied BGRA.
fn recording_chip_bitmap(
    _chip: &crate::capture::RecordingChipData,
    scale: f64,
) -> (Vec<u8>, Size<i32, Buffer>) {
    let integer_scale = scale.round().max(1.0);
    let width = (RECORDING_CHIP_WIDTH * integer_scale).round() as i32;
    let height = (RECORDING_CHIP_HEIGHT * integer_scale).round() as i32;

    // The pill spans the full height; the red circle sits at the left
    // with a logical inset.
    let radius = height as f32 / 2.0;
    let dot_radius = (height as f32 * 0.2).max(4.0);
    let dot_center_x = (9.0 * integer_scale) as f32 + dot_radius;
    let dot_center_y = height as f32 / 2.0;

    // The background keeps some translucency so the desktop shows
    // through faintly; the red circle blends over it on its left edge.
    const BACKGROUND_OPACITY: f32 = 0.78;

    let mut data = vec![0u8; (width * height * 4) as usize];
    for y in 0..height {
        for x in 0..width {
            let px = x as f32 + 0.5;
            let py = y as f32 + 0.5;

            // Signed distance of a pill: rounded rect whose radius is
            // half the height.
            let center_x = width as f32 / 2.0;
            let center_y = height as f32 / 2.0;
            let half_height = radius;
            let qx = (px - center_x).abs() - (center_x - radius);
            let qy = (py - center_y).abs() - (half_height - radius);
            let outside = (qx.max(0.0)).hypot(qy.max(0.0));
            let pill_distance = outside + qx.max(qy).min(0.0) - radius;
            let alpha_bg =
                (((0.5 - pill_distance).clamp(0.0, 1.0) * BACKGROUND_OPACITY) * 255.0).round();

            let dot_distance = ((px - dot_center_x).hypot(py - dot_center_y)) - dot_radius;
            let dot_coverage = (0.5 - dot_distance).clamp(0.0, 1.0);
            let alpha_dot = (dot_coverage * 255.0).round();

            // Memory byte order for Argb8888 is blue, green, red, alpha;
            // premultiplied white coverage and red: (26, 0, 255).
            let destination = (y * width + x) as usize * 4;
            if alpha_dot > alpha_bg || dot_distance <= 0.0 {
                data[destination..destination + 4].copy_from_slice(&[
                    (26.0 * dot_coverage) as u8,
                    0,
                    (255.0 * dot_coverage) as u8,
                    alpha_dot as u8,
                ]);
            } else {
                data[destination..destination + 4].copy_from_slice(&[0, 0, 0, alpha_bg as u8]);
            }
        }
    }
    (data, Size::from((width, height)))
}

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
    idle_dim_alpha: f32,
    surfaces_in_gaming_mode: Vec<&WlSurface>,
    capture_overlay: Option<&CaptureSession>,
    recording_chip: Option<crate::capture::RecordingChipData>,
) -> Vec<VeshellRenderElements<R>>
where
    R: Renderer + ImportAll + ImportMem + ImportDma,
    <R as RendererSuper>::TextureId: Send + Clone + 'static,
    <R as RendererSuper>::Error:,
    VeshellRenderElements<R>: RenderElement<R>,
{
    let scale = output.current_scale();
    let mut elements: Vec<VeshellRenderElements<R>> = Vec::new();

    // The screensaver dim overlay is the topmost element while active:
    // pushed first because the damage tracker paints deepest-first. It is
    // never drawn during a capture session (the frozen frame must stay
    // clean) and only once the fade has begun.
    if idle_dim_alpha > 0.001 && capture_overlay.is_none() {
        let width = (output_geometry.size.w * scale.fractional_scale()).ceil() as i32;
        let height = (output_geometry.size.h * scale.fractional_scale()).ceil() as i32;
        let color = [
            DIM_BASE_COLOR[0],
            DIM_BASE_COLOR[1],
            DIM_BASE_COLOR[2],
            DIM_BASE_COLOR[3] * idle_dim_alpha,
        ];
        elements.push(VeshellRenderElements::Solid(
            solid::SolidColorRenderElement::new(
                stable_solid_id(ID_IDLE_DIM),
                Rectangle::new((0, 0).into(), (width, height).into()),
                1,
                Color32F::new(color[0], color[1], color[2], color[3]),
                Kind::Unspecified,
            ),
        ));
    }

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
    // The live recording indicator rides the same overlay layer; the
    // capture readback path (get_frame_elements_from_dmabuf) draws none
    // of it, so the chip never reaches the recorded pixels.
    if let Some(chip) = recording_chip {
        elements.extend(get_recording_overlay_elements(
            renderer,
            output_geometry,
            scale.fractional_scale(),
            chip,
        ));
    }

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

#[cfg(test)]
mod counter_bitmap_tests {
    use super::*;

    fn test_chip(seconds: u64) -> crate::capture::RecordingChipData {
        crate::capture::RecordingChipData {
            outline: Rectangle::new(Point::new(0.0, 0.0), (200.0, 100.0).into()),
            chip: Rectangle::new(Point::new(0.0, 0.0), (84.0, 26.0).into()),
            seconds,
        }
    }

    #[test]
    fn counter_bitmap_is_rasterized() {
        let (data, size) = recording_counter_bitmap(&test_chip(63), 1.0).expect("bitmap built");
        assert!(size.w > 20 && size.h > 8, "size {size:?}");
        let bytes = size.w * size.h * 4;
        assert_eq!(data.len() as i32, bytes);
        let max = data.iter().max().copied().unwrap_or(0);
        let bright = data.iter().filter(|byte| **byte > 128).count();
        assert!(
            max == 255 || max > 0,
            "max coverage {max}, bright bytes {bright}"
        );
        eprintln!("bitmap size {size:?}, max {max}, bright bytes {bright}");
    }

    #[test]
    fn chip_bitmap_is_pill_with_red_dot() {
        let (data, size) = recording_chip_bitmap(&test_chip(63), 1.0);
        assert_eq!((size.w, size.h), (84, 26));
        let stride = size.w as usize;
        let alpha_at = |x: usize, y: usize| data[(y * stride + x) * 4 + 3];
        // Corners outside the pill remain fully transparent.
        assert_eq!(alpha_at(0, 0), 0);
        assert_eq!(alpha_at(stride - 1, 0), 0);
        // The pill center is the translucent background.
        let center = alpha_at(stride / 2, 13);
        assert!(
            (center as i32 - 199).abs() <= 6,
            "background alpha {center}"
        );
        // The dot on the left is fully red (alpha seek the byte with
        // red 255).
        for x in 9..16 {
            let index = (13 * stride + x) * 4;
            if data[index + 2] == 255 {
                assert!(data[index + 3] == 255, "dot alpha at {x}");
                return;
            }
        }
        panic!("no full-red pixel found in the dot area");
    }
}
