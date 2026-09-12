use std::fs::{self, File};
use std::io::Write;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use serde::Deserialize;
use smithay::backend::allocator::dmabuf::{AsDmabuf, Dmabuf};
use smithay::backend::allocator::{Fourcc, Slot};
use smithay::backend::renderer::damage::OutputDamageTracker;
use smithay::backend::renderer::gles::{GlesRenderbuffer, GlesRenderer};
use smithay::backend::renderer::{Bind, ExportMem, Offscreen};
use smithay::output::Output;
use smithay::reexports::calloop::timer::{TimeoutAction, Timer};
use smithay::utils::{Physical, Rectangle, Size, Transform};
use smithay::wayland::selection::data_device::set_data_device_selection;
use smithay::wayland::selection::SelectionTarget;
use tracing::warn;

use crate::backend::render::get_render_elements_from_dmabuf;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::flutter_engine::view::OutputViewIdWrapper;
use crate::state::{NATIVE_SCREENSHOT_MIME, PNG_MIME};
use crate::{Backend, State};

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DesktopArea {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScreenshotRequest {
    pub rect: DesktopArea,
    #[serde(default)]
    pub revision: Option<u64>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PreparedScreenshotRequest {
    pub id: u64,
}

pub struct PreparedScreenshot {
    id: u64,
    area: DesktopArea,
    layout_revision: u64,
    view_generations: Vec<(i64, Option<u64>)>,
}

pub struct PendingScreenshot {
    prepared: PreparedScreenshot,
    result: Option<Box<dyn MethodResult<serde_json::Value>>>,
}

struct OutputCaptureInput {
    output: Output,
    geometry: Rectangle<f64, smithay::utils::Logical>,
    flutter_dmabuf: Dmabuf,
    game_surface_list: Vec<smithay::reexports::wayland_server::protocol::wl_surface::WlSurface>,
}

struct CapturedOutput {
    geometry: Rectangle<f64, smithay::utils::Logical>,
    size: Size<i32, Physical>,
    pixels: Vec<u8>,
}

pub fn prepare_desktop_area_screenshot<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    area: DesktopArea,
    revision: Option<u64>,
) -> Result<u64, String> {
    if state.pending_screenshot.is_some() {
        return Err("A screenshot is already in progress".to_string());
    }

    let area = area.rectangle()?;
    if revision.is_some_and(|revision| revision != state.output_layout_revision) {
        return Err("Output layout changed during screenshot selection".to_string());
    }
    let view_generations = capture_view_generations(state, area)?;
    let id = state.next_screenshot_id;
    state.next_screenshot_id = state.next_screenshot_id.wrapping_add(1);
    state.pending_screenshot = Some(PendingScreenshot {
        prepared: PreparedScreenshot {
            id,
            area: DesktopArea {
                x: area.loc.x,
                y: area.loc.y,
                width: area.size.w,
                height: area.size.h,
            },
            layout_revision: state.output_layout_revision,
            view_generations,
        },
        result: None,
    });
    let loop_handle = state.loop_handle.clone();
    if let Err(error) = loop_handle.insert_source(
        Timer::from_duration(Duration::from_secs(5)),
        move |_, _, state| {
            cancel_pending_screenshot_if_id(
                state,
                id,
                "Screenshot capture timed out waiting for a presented frame",
            );
            TimeoutAction::Drop
        },
    ) {
        state.pending_screenshot = None;
        return Err(format!("Unable to schedule screenshot timeout: {error}"));
    }
    Ok(id)
}

pub fn queue_prepared_screenshot<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    id: u64,
    result: Box<dyn MethodResult<serde_json::Value>>,
) {
    let Some(mut pending) = state.pending_screenshot.take() else {
        return_result_error(
            result,
            "No prepared screenshot matches this request".to_string(),
        );
        return;
    };
    if pending.prepared.id != id {
        state.pending_screenshot = Some(pending);
        return_result_error(
            result,
            "No prepared screenshot matches this request".to_string(),
        );
        return;
    }
    if pending.prepared.layout_revision != state.output_layout_revision {
        return_result_error(
            result,
            "Output layout changed during screenshot selection".to_string(),
        );
        return;
    }
    if pending.result.is_some() {
        state.pending_screenshot = Some(pending);
        return_result_error(result, "Screenshot capture is already queued".to_string());
        return;
    }

    pending.result = Some(result);
    state.pending_screenshot = Some(pending);
    complete_pending_screenshot(state);
}

pub fn cancel_pending_screenshot<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    message: &str,
) {
    let Some(pending) = state.pending_screenshot.take() else {
        return;
    };
    if let Some(result) = pending.result {
        return_result_error(result, message.to_string());
    }
}

fn cancel_pending_screenshot_if_id<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    id: u64,
    message: &str,
) {
    if state
        .pending_screenshot
        .as_ref()
        .is_some_and(|pending| pending.prepared.id == id)
    {
        cancel_pending_screenshot(state, message);
    }
}

pub fn complete_pending_screenshot<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    let Some(pending) = state.pending_screenshot.as_ref() else {
        return;
    };
    if pending.prepared.layout_revision != state.output_layout_revision {
        let pending = state.pending_screenshot.take().unwrap();
        if let Some(result) = pending.result {
            return_result_error(
                result,
                "Output layout changed during screenshot selection".to_string(),
            );
        }
        return;
    }
    if pending.result.is_none() {
        return;
    }
    if !has_new_presented_frames(state, &pending.prepared.view_generations) {
        return;
    }

    let pending = state.pending_screenshot.take().unwrap();
    let result = pending.result.unwrap();
    match save_desktop_area_screenshot(state, pending.prepared.area) {
        Ok(path) => {
            let mut result = result;
            result.success(Some(serde_json::json!({ "path": path })));
        }
        Err(message) => return_result_error(result, message),
    }
}

fn return_result_error(mut result: Box<dyn MethodResult<serde_json::Value>>, message: String) {
    result.error("screenshot_failed".to_string(), message, None);
}

pub fn save_desktop_area_screenshot<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    area: DesktopArea,
) -> Result<PathBuf, String> {
    let area = area.rectangle()?;
    let (inputs, capture_scale) = output_capture_inputs(state, area)?;
    let pointer_location = state.pointer.current_location();
    let now = state.clock.now();
    let is_surface_under_pointer = state.surface_id_under_cursor.is_some();

    let captured_outputs = state
        .backend_data
        .with_primary_renderer_mut(|renderer| {
            inputs
                .iter()
                .map(|input| {
                    let bytes = render_output_to_memory(
                        renderer,
                        &input.output,
                        &input.flutter_dmabuf,
                        input.geometry,
                        now,
                        &state.cursor_image_status,
                        &state.cursor_state,
                        pointer_location,
                        is_surface_under_pointer,
                        BackendData::FLIP_FLUTTER_TEXTURE,
                        input.game_surface_list.iter().collect(),
                    )?;
                    let (size, pixels) = orient_readback(&input.output, bytes)?;
                    Ok(CapturedOutput {
                        geometry: input.geometry,
                        size,
                        pixels,
                    })
                })
                .collect::<Result<Vec<_>, String>>()
        })
        .ok_or_else(|| "No renderer is available to capture the output".to_string())??;

    let (size, pixels) = compose_desktop_area(area, capture_scale, &captured_outputs)?;
    let (path, png) = write_png(size, pixels)?;
    if let Some(xwm) = state
        .xwayland_state
        .as_mut()
        .and_then(|state| state.xwm.as_mut())
    {
        if let Err(error) = xwm.new_selection(
            SelectionTarget::Clipboard,
            Some(vec![
                PNG_MIME.to_string(),
                NATIVE_SCREENSHOT_MIME.to_string(),
            ]),
        ) {
            warn!(?error, "Failed to publish native screenshot to XWayland");
        }
    }
    set_data_device_selection(
        &state.display_handle,
        &state.seat,
        vec![PNG_MIME.to_string(), NATIVE_SCREENSHOT_MIME.to_string()],
        Some(Arc::new(png)),
    );
    Ok(path)
}

impl DesktopArea {
    fn rectangle(self) -> Result<Rectangle<f64, smithay::utils::Logical>, String> {
        if !self.x.is_finite()
            || !self.y.is_finite()
            || !self.width.is_finite()
            || !self.height.is_finite()
            || self.width <= 0.
            || self.height <= 0.
        {
            return Err(
                "Capture rectangle must have finite coordinates and positive dimensions"
                    .to_string(),
            );
        }
        Ok(Rectangle::new(
            (self.x, self.y).into(),
            (self.width, self.height).into(),
        ))
    }
}

fn output_capture_inputs<BackendData: Backend + 'static>(
    state: &State<BackendData>,
    area: Rectangle<f64, smithay::utils::Logical>,
) -> Result<(Vec<OutputCaptureInput>, f64), String> {
    let mut inputs = Vec::new();
    let mut capture_scale: f64 = 0.0;

    for output in state.space.outputs().cloned() {
        let geometry = state
            .space
            .output_geometry(&output)
            .ok_or_else(|| format!("Output {} has no geometry", output.name()))?
            .to_f64();
        if area.intersection(geometry).is_none() {
            continue;
        }

        let view_id = output
            .user_data()
            .get::<OutputViewIdWrapper>()
            .ok_or_else(|| format!("Output {} has no Flutter view", output.name()))?
            .view_id;
        let flutter_dmabuf = latest_flutter_dmabuf(state, view_id)?;
        let output_name = output.name();
        let game_surface_list = state
            .meta_window_state
            .meta_windows
            .values()
            .filter_map(|meta_window| {
                (meta_window.game_mode_activated
                    && meta_window.current_output.as_deref() == Some(output_name.as_str()))
                .then(|| state.surfaces.get(&meta_window.surface_id).cloned())
                .flatten()
            })
            .collect();

        capture_scale = capture_scale.max(output.current_scale().fractional_scale());
        inputs.push(OutputCaptureInput {
            output,
            geometry,
            flutter_dmabuf,
            game_surface_list,
        });
    }

    if inputs.is_empty() {
        return Err("Capture rectangle does not intersect any output".to_string());
    }
    if inputs.len() != 1 {
        return Err("Capture selection must stay within one physical output".to_string());
    }
    Ok((inputs, capture_scale))
}

fn capture_view_generations<BackendData: Backend + 'static>(
    state: &State<BackendData>,
    area: Rectangle<f64, smithay::utils::Logical>,
) -> Result<Vec<(i64, Option<u64>)>, String> {
    let mut views = Vec::new();
    for output in state.space.outputs() {
        let geometry = state
            .space
            .output_geometry(output)
            .ok_or_else(|| format!("Output {} has no geometry", output.name()))?
            .to_f64();
        if area.intersection(geometry).is_none() {
            continue;
        }
        let view_id = output
            .user_data()
            .get::<OutputViewIdWrapper>()
            .ok_or_else(|| format!("Output {} has no Flutter view", output.name()))?
            .view_id;
        let generation = state
            .flutter_engine()
            .views_management
            .views
            .get(&view_id)
            .and_then(|view| view.last_rendered_generation);
        views.push((view_id, generation));
    }
    if views.is_empty() {
        return Err("Capture rectangle does not intersect any output".to_string());
    }
    Ok(views)
}

fn has_new_presented_frames<BackendData: Backend + 'static>(
    state: &State<BackendData>,
    expected_generations: &[(i64, Option<u64>)],
) -> bool {
    all_views_have_new_generations(expected_generations, |view_id| {
        state
            .flutter_engine()
            .views_management
            .views
            .get(&view_id)
            .map(|view| view.last_rendered_generation)
    })
}

fn all_views_have_new_generations(
    expected_generations: &[(i64, Option<u64>)],
    mut current_generation: impl FnMut(i64) -> Option<Option<u64>>,
) -> bool {
    expected_generations
        .iter()
        .all(|(view_id, expected_generation)| {
            current_generation(*view_id).is_some_and(|current| current != *expected_generation)
        })
}

fn compose_desktop_area(
    area: Rectangle<f64, smithay::utils::Logical>,
    scale: f64,
    outputs: &[CapturedOutput],
) -> Result<(Size<i32, Physical>, Vec<u8>), String> {
    let size = pixel_size(area.size, scale)?;
    let mut pixels = vec![0; pixel_len(size)?];
    for pixel in pixels.chunks_exact_mut(4) {
        pixel[3] = 255;
    }

    for output in outputs {
        let Some(intersection) = area.intersection(output.geometry) else {
            continue;
        };
        let mut destination = scaled_bounds(intersection, area.loc, scale, scale)?;
        let area_right = area.loc.x + area.size.w;
        let area_bottom = area.loc.y + area.size.h;
        if intersection.loc.x + intersection.size.w == area_right {
            destination.size.w = size.w - destination.loc.x;
        }
        if intersection.loc.y + intersection.size.h == area_bottom {
            destination.size.h = size.h - destination.loc.y;
        }
        let source = scaled_bounds(
            intersection,
            output.geometry.loc,
            output.size.w as f64 / output.geometry.size.w,
            output.size.h as f64 / output.geometry.size.h,
        )?;
        blit_scaled(
            &mut pixels,
            size,
            &output.pixels,
            output.size,
            destination,
            source,
        )?;
    }

    Ok((size, pixels))
}

fn pixel_size(
    size: Size<f64, smithay::utils::Logical>,
    scale: f64,
) -> Result<Size<i32, Physical>, String> {
    if !scale.is_finite() || scale <= 0. {
        return Err("Capture scale must be finite and positive".to_string());
    }
    let width = (size.w * scale).ceil();
    let height = (size.h * scale).ceil();
    if !width.is_finite()
        || !height.is_finite()
        || width <= 0.
        || height <= 0.
        || width > i32::MAX as f64
        || height > i32::MAX as f64
    {
        return Err("Capture rectangle is too large".to_string());
    }
    Ok((width as i32, height as i32).into())
}

fn pixel_len(size: Size<i32, Physical>) -> Result<usize, String> {
    usize::try_from(size.w)
        .ok()
        .and_then(|width| {
            usize::try_from(size.h)
                .ok()
                .and_then(|height| width.checked_mul(height))
        })
        .and_then(|pixels| pixels.checked_mul(4))
        .ok_or_else(|| "Capture buffer is too large".to_string())
}

fn scaled_bounds(
    rectangle: Rectangle<f64, smithay::utils::Logical>,
    origin: smithay::utils::Point<f64, smithay::utils::Logical>,
    scale_x: f64,
    scale_y: f64,
) -> Result<Rectangle<i32, Physical>, String> {
    let left = ((rectangle.loc.x - origin.x) * scale_x).round();
    let top = ((rectangle.loc.y - origin.y) * scale_y).round();
    let right = ((rectangle.loc.x + rectangle.size.w - origin.x) * scale_x).round();
    let bottom = ((rectangle.loc.y + rectangle.size.h - origin.y) * scale_y).round();
    if !left.is_finite()
        || !top.is_finite()
        || !right.is_finite()
        || !bottom.is_finite()
        || left < i32::MIN as f64
        || top < i32::MIN as f64
        || right > i32::MAX as f64
        || bottom > i32::MAX as f64
    {
        return Err("Capture bounds are invalid".to_string());
    }
    Ok(Rectangle::new(
        (left as i32, top as i32).into(),
        ((right - left) as i32, (bottom - top) as i32).into(),
    ))
}

fn blit_scaled(
    destination_pixels: &mut [u8],
    destination_size: Size<i32, Physical>,
    source_pixels: &[u8],
    source_size: Size<i32, Physical>,
    destination: Rectangle<i32, Physical>,
    source: Rectangle<i32, Physical>,
) -> Result<(), String> {
    if destination.size.w <= 0
        || destination.size.h <= 0
        || source.size.w <= 0
        || source.size.h <= 0
    {
        return Ok(());
    }
    if source.loc.x < 0
        || source.loc.y < 0
        || source.loc.x + source.size.w > source_size.w
        || source.loc.y + source.size.h > source_size.h
        || destination.loc.x < 0
        || destination.loc.y < 0
        || destination.loc.x + destination.size.w > destination_size.w
        || destination.loc.y + destination.size.h > destination_size.h
    {
        return Err("Capture bounds are outside the source image".to_string());
    }

    let destination_width = destination_size.w as usize;
    let source_width = source_size.w as usize;
    for y in 0..destination.size.h as usize {
        let source_y =
            source.loc.y as usize + y * source.size.h as usize / destination.size.h as usize;
        for x in 0..destination.size.w as usize {
            let source_x =
                source.loc.x as usize + x * source.size.w as usize / destination.size.w as usize;
            let source_offset = (source_y * source_width + source_x) * 4;
            let destination_offset = ((destination.loc.y as usize + y) * destination_width
                + destination.loc.x as usize
                + x)
                * 4;
            destination_pixels[destination_offset..destination_offset + 4]
                .copy_from_slice(&source_pixels[source_offset..source_offset + 4]);
        }
    }
    Ok(())
}

fn latest_flutter_dmabuf<BackendData: Backend + 'static>(
    state: &State<BackendData>,
    view_id: i64,
) -> Result<Dmabuf, String> {
    let view = state
        .flutter_engine()
        .views_management
        .views
        .get(&view_id)
        .ok_or_else(|| format!("Flutter view {view_id} is missing"))?;
    let slot: &Slot<Dmabuf> = view
        .last_rendered_slot
        .as_ref()
        .ok_or_else(|| "Flutter has not rendered this output yet".to_string())?;
    slot.export()
        .map_err(|error| format!("Unable to export Flutter frame: {error}"))
}

#[allow(clippy::too_many_arguments)]
fn render_output_to_memory(
    renderer: &mut GlesRenderer,
    output: &Output,
    flutter_dmabuf: &Dmabuf,
    output_geometry: Rectangle<f64, smithay::utils::Logical>,
    now: smithay::utils::Time<smithay::utils::Monotonic>,
    cursor_image_status: &std::sync::Mutex<smithay::input::pointer::CursorImageStatus>,
    cursor_state: &std::sync::Mutex<crate::cursor::CursorStateInner>,
    pointer_location: smithay::utils::Point<f64, smithay::utils::Logical>,
    is_surface_under_pointer: bool,
    flip_flutter_texture: bool,
    game_surface_list: Vec<&smithay::reexports::wayland_server::protocol::wl_surface::WlSurface>,
) -> Result<Vec<u8>, String> {
    let mode = output
        .current_mode()
        .ok_or_else(|| format!("Output {} has no mode", output.name()))?;
    let size = mode
        .size
        .to_logical(1)
        .to_buffer(1, smithay::utils::Transform::Normal);
    let mut target_buffer =
        Offscreen::<GlesRenderbuffer>::create_buffer(renderer, Fourcc::Abgr8888, size)
            .map_err(|error| format!("Unable to create capture buffer: {error}"))?;
    let mut target = renderer
        .bind(&mut target_buffer)
        .map_err(|error| format!("Unable to bind capture buffer: {error}"))?;
    let elements = get_render_elements_from_dmabuf(
        renderer,
        output,
        flutter_dmabuf,
        output_geometry,
        now,
        cursor_image_status,
        cursor_state,
        pointer_location,
        is_surface_under_pointer,
        flip_flutter_texture,
        game_surface_list,
    );
    let mut damage_tracker = OutputDamageTracker::from_output(output);
    damage_tracker
        .render_output(renderer, &mut target, 0, &elements, [0.0, 0.0, 0.0, 1.0])
        .map_err(|error| format!("Unable to render capture: {error}"))?;
    let mapping = renderer
        .copy_framebuffer(&target, Rectangle::from_size(size), Fourcc::Abgr8888)
        .map_err(|error| format!("Unable to read capture buffer: {error}"))?;
    renderer
        .map_texture(&mapping)
        .map(|pixels| pixels.to_vec())
        .map_err(|error| format!("Unable to map capture buffer: {error}"))
}

fn orient_readback(
    output: &Output,
    pixels: Vec<u8>,
) -> Result<(Size<i32, Physical>, Vec<u8>), String> {
    let mode = output
        .current_mode()
        .ok_or_else(|| format!("Output {} has no mode", output.name()))?;
    orient_pixels(pixels, mode.size, output.current_transform())
}

fn orient_pixels(
    readback_pixels: Vec<u8>,
    source_size: Size<i32, Physical>,
    transform: Transform,
) -> Result<(Size<i32, Physical>, Vec<u8>), String> {
    let source_width = usize::try_from(source_size.w)
        .map_err(|_| "Capture buffer width must be positive".to_string())?;
    let source_height = usize::try_from(source_size.h)
        .map_err(|_| "Capture buffer height must be positive".to_string())?;
    let expected_len = source_width
        .checked_mul(source_height)
        .and_then(|pixels| pixels.checked_mul(4))
        .ok_or_else(|| "Capture buffer is too large".to_string())?;
    if readback_pixels.len() != expected_len {
        return Err(format!(
            "Capture buffer has {} bytes, expected {expected_len}",
            readback_pixels.len()
        ));
    }

    let target_size = transform.transform_size(source_size);
    let target_width = usize::try_from(target_size.w)
        .map_err(|_| "Capture target width must be positive".to_string())?;
    let mut pixels = vec![0; expected_len];

    for source_y in 0..source_height {
        for source_x in 0..source_width {
            // Smithay's mapped framebuffer uses top-origin pixel rows, like PNG.
            let source = Rectangle::new((source_x as i32, source_y as i32).into(), (1, 1).into());
            let target = transform.transform_rect_in(source, &source_size);
            let readback_offset = (source_y * source_width + source_x) * 4;
            let target_offset = (target.loc.y as usize * target_width + target.loc.x as usize) * 4;
            pixels[target_offset..target_offset + 4]
                .copy_from_slice(&readback_pixels[readback_offset..readback_offset + 4]);
        }
    }

    Ok((target_size, pixels))
}

fn write_png(size: Size<i32, Physical>, pixels: Vec<u8>) -> Result<(PathBuf, Vec<u8>), String> {
    let path = screenshot_directory()?.join(format!(
        "Veshell Screenshot {}.png",
        chrono::Local::now().format("%Y-%m-%d %H-%M-%S%.3f")
    ));
    let png = encode_png(size, pixels)
        .map_err(|error| format!("Unable to encode screenshot {}: {error}", path.display()))?;
    File::create(&path)
        .and_then(|mut file| file.write_all(&png))
        .map_err(|error| format!("Unable to write screenshot {}: {error}", path.display()))?;
    Ok((path, png))
}

fn encode_png(size: Size<i32, Physical>, pixels: Vec<u8>) -> Result<Vec<u8>, png::EncodingError> {
    let mut png = Vec::new();
    let mut encoder = png::Encoder::new(&mut png, size.w as u32, size.h as u32);
    encoder.set_color(png::ColorType::Rgba);
    encoder.set_depth(png::BitDepth::Eight);
    encoder
        .write_header()
        .and_then(|mut writer| writer.write_image_data(&pixels))?;
    Ok(png)
}

fn screenshot_directory() -> Result<PathBuf, String> {
    let path = xdg_user::pictures()
        .ok()
        .flatten()
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join("Pictures")))
        .ok_or_else(|| "Unable to determine the screenshot directory".to_string())?;
    fs::create_dir_all(&path).map_err(|error| {
        format!(
            "Unable to create screenshot directory {}: {error}",
            path.display()
        )
    })?;
    Ok(path)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn readback_is_already_in_png_coordinates() {
        let top_left = [1, 2, 3, 4];
        let top_right = [5, 6, 7, 8];
        let bottom_left = [9, 10, 11, 12];
        let bottom_right = [13, 14, 15, 16];
        let readback = [top_left, top_right, bottom_left, bottom_right].concat();

        let (size, pixels) = orient_pixels(readback, (2, 2).into(), Transform::Normal).unwrap();

        assert_eq!(size, (2, 2).into());
        assert_eq!(
            pixels,
            [top_left, top_right, bottom_left, bottom_right].concat()
        );
    }

    #[test]
    fn screenshot_png_is_encoded_for_clipboard_and_file() {
        let encoded = encode_png((1, 1).into(), vec![1, 2, 3, 255]).unwrap();

        assert_eq!(&encoded[..8], b"\x89PNG\r\n\x1a\n");
    }

    #[test]
    fn readback_is_oriented_for_rotated_outputs() {
        let top_left = [1, 2, 3, 4];
        let top_right = [5, 6, 7, 8];
        let bottom_left = [9, 10, 11, 12];
        let bottom_right = [13, 14, 15, 16];
        let readback = [top_left, top_right, bottom_left, bottom_right].concat();

        let (size, pixels) = orient_pixels(readback, (2, 2).into(), Transform::_90).unwrap();

        assert_eq!(size, (2, 2).into());
        assert_eq!(
            pixels,
            [bottom_left, top_left, bottom_right, top_right].concat()
        );
    }

    #[test]
    fn desktop_area_composes_intersecting_outputs() {
        let area = Rectangle::new((0., 0.).into(), (4., 1.).into());
        let outputs = [
            CapturedOutput {
                geometry: Rectangle::new((0., 0.).into(), (2., 1.).into()),
                size: (2, 1).into(),
                pixels: [255, 0, 0, 255, 255, 0, 0, 255].to_vec(),
            },
            CapturedOutput {
                geometry: Rectangle::new((2., 0.).into(), (2., 1.).into()),
                size: (2, 1).into(),
                pixels: [0, 0, 255, 255, 0, 0, 255, 255].to_vec(),
            },
        ];

        let (size, pixels) = compose_desktop_area(area, 1., &outputs).unwrap();

        assert_eq!(size, (4, 1).into());
        assert_eq!(
            pixels,
            [255, 0, 0, 255, 255, 0, 0, 255, 0, 0, 255, 255, 0, 0, 255, 255,]
        );
    }

    #[test]
    fn desktop_area_leaves_desktop_gaps_opaque_black() {
        let area = Rectangle::new((0., 0.).into(), (3., 1.).into());
        let outputs = [CapturedOutput {
            geometry: Rectangle::new((1., 0.).into(), (1., 1.).into()),
            size: (1, 1).into(),
            pixels: [0, 255, 0, 255].to_vec(),
        }];

        let (_, pixels) = compose_desktop_area(area, 1., &outputs).unwrap();

        assert_eq!(pixels, [0, 0, 0, 255, 0, 255, 0, 255, 0, 0, 0, 255]);
    }

    #[test]
    fn screenshot_waits_for_every_participating_view() {
        let expected = [(1, Some(3)), (2, Some(5))];

        assert!(!all_views_have_new_generations(
            &expected,
            |view_id| match view_id {
                1 => Some(Some(4)),
                2 => Some(Some(5)),
                _ => None,
            }
        ));
        assert!(all_views_have_new_generations(
            &expected,
            |view_id| match view_id {
                1 => Some(Some(4)),
                2 => Some(Some(6)),
                _ => None,
            }
        ));
        assert!(!all_views_have_new_generations(&expected, |_| None));
    }
}
