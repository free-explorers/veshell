use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::thread;

pub mod pipewire;
pub mod recording;

use smithay::backend::allocator::dmabuf::{AsDmabuf, Dmabuf};
use smithay::backend::allocator::{Fourcc, Slot};
use smithay::backend::renderer::damage::OutputDamageTracker;
use smithay::backend::renderer::gles::{GlesRenderbuffer, GlesRenderer};
use smithay::backend::renderer::{Bind, ExportMem, Offscreen};
use smithay::output::Output;
use smithay::reexports::calloop::{channel, LoopHandle};
use smithay::utils::{Logical, Physical, Point, Rectangle, Size, Transform};
use smithay::wayland::selection::data_device::set_data_device_selection;
use smithay::wayland::selection::SelectionTarget;
use tracing::{debug, info, warn};

use crate::backend::render::get_frame_elements_from_dmabuf;
use crate::flutter_engine::view::OutputViewIdWrapper;
use crate::state::{NATIVE_SCREENSHOT_MIME, PNG_MIME};
use crate::{Backend, State};

const BTN_LEFT: u32 = 0x110;

/// A capture-owned copy of the frozen desktop, taken when the session begins.
pub struct CaptureSnapshot {
    pub size: Size<i32, Physical>,
    pub scale: f64,
    pub pixels: Vec<u8>,
}

/// A live screenshot-selection session.
///
/// Entered when the user presses the compositor's own screenshot hotkey
/// (print screen). The moment it starts, its [CaptureSnapshot] is rendered
/// into capture-owned CPU storage: Flutter and Wayland clients receive no
/// input while the session runs, and Flutter framing stores presented during
/// the session are dropped instead of replacing the frame the user saw at
/// hotkey time (`VeshellView::hold_backing_store`), but the desktop visual
/// the user composes against stays owned by the capture, never by a
/// swapchain buffer that could be recycled.
///
/// The cursor is not part of the captured image: while the session runs a
/// native crosshair is drawn instead (see the render side) and the snapshot
/// renders the frozen frame without any cursor.
///
/// The selection is drawn natively over the output the pointer was on when
/// the hotkey fired; the drag is confined to [output_geometry].
pub struct CaptureSession {
    pub output: Output,
    pub output_geometry: Rectangle<f64, Logical>,
    pub snapshot: Option<CaptureSnapshot>,
    pub start: Option<Point<f64, Logical>>,
    pub current: Point<f64, Logical>,
    pub record: bool,
}

impl CaptureSession {
    /// The logical selection rectangle, or None if no drag has started yet
    /// or the drag area is empty (a click without drag).
    pub fn selection(&self) -> Option<Rectangle<f64, Logical>> {
        let start = self.start?;
        let x_min = start.x.min(self.current.x);
        let y_min = start.y.min(self.current.y);
        let width = start.x.max(self.current.x) - x_min;
        let height = start.y.max(self.current.y) - y_min;
        let rect = Rectangle::new((x_min, y_min).into(), (width, height).into());
        (rect.size.w > 0.0 && rect.size.h > 0.0).then_some(rect)
    }

    /// Clamps a point within this session's output geometry.
    pub fn clamp_in_output(&self, point: Point<f64, Logical>) -> Point<f64, Logical> {
        let mut x = point.x;
        let mut y = point.y;
        x = x.clamp(
            self.output_geometry.loc.x,
            self.output_geometry.loc.x + self.output_geometry.size.w,
        );
        y = y.clamp(
            self.output_geometry.loc.y,
            self.output_geometry.loc.y + self.output_geometry.size.h,
        );
        (x, y).into()
    }
}

/// Starts a screenshot session, freezing the desktop at the current state.
///
/// Returns true when a session started (the caller must swallow the event).
pub fn begin_capture_session<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    pointer_location: Point<f64, Logical>,
    record: bool,
) {
    let Some((output, geometry)) = state
        .space
        .outputs()
        .find_map(|output| {
            state
                .space
                .output_geometry(output)
                .map(|geometry| (output, geometry.to_f64()))
                .filter(|(_, geometry)| geometry.contains(pointer_location))
        })
        .or_else(|| {
            state.space.outputs().next().and_then(|output| {
                state
                    .space
                    .output_geometry(output)
                    .map(|geometry| (output, geometry.to_f64()))
            })
        })
        .map(|(output, geometry)| (output.clone(), geometry))
    else {
        warn!("Unable to start a screenshot session without any output");
        return;
    };

    let snapshot = match take_output_snapshot(state, &output) {
        Ok(snapshot) => snapshot,
        Err(message) => {
            warn!("Unable to start a screenshot session: {message}");
            return;
        }
    };

    info!(
        pointer_location = ?pointer_location,
        record,
        "Entering capture mode"
    );
    state.capture_session = Some(CaptureSession {
        output,
        output_geometry: geometry,
        snapshot: Some(snapshot),
        start: None,
        current: pointer_location,
        record,
    });
}

/// Ends the session by teleporting the compositor pointer back to the last
/// tracked selection position.
///
/// Pointer motion was short-circuited during the session, so the Smithay
/// pointer is still at the hotkey-press location; without this the cursor
/// would visibly jump back there after the frozen desktop clears.
/// `set_location` deliberately sends no events and touches no focus.
fn end_capture_session<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    let Some(session) = state.capture_session.take() else {
        return;
    };
    state.pointer.set_location(session.current);
}

/// Cancels the running session without taking a screenshot.
pub fn cancel_capture_session<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    if state.capture_session.is_some() {
        end_capture_session(state);
        info!("Screenshot capture cancelled");
    }
}

pub fn capture_pointer_press<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    button_code: u32,
) {
    let Some(session) = state.capture_session.as_mut() else {
        return;
    };
    // Primary button starts (or restarts) a drag; other buttons cancel.
    if button_code == BTN_LEFT {
        session.start = Some(session.current);
    } else {
        end_capture_session(state);
        info!("Screenshot capture cancelled by button");
    }
}

/// Accumulates a relative motion event (its `delta()` is a logical point)
/// into the session's tracked position.
pub fn capture_pointer_motion_delta<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    delta: Point<f64, Logical>,
) {
    let Some(session) = state.capture_session.as_mut() else {
        return;
    };
    session.current =
        session.clamp_in_output((session.current.x + delta.x, session.current.y + delta.y).into());
}

/// Replaces the session's tracked position with an absolute motion event.
pub fn capture_pointer_motion_to<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    next: Point<f64, Logical>,
) {
    let Some(session) = state.capture_session.as_mut() else {
        return;
    };
    session.current = session.clamp_in_output(next);
}

pub fn capture_pointer_release<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    button_code: u32,
) {
    if state.capture_session.is_none() {
        return;
    }
    // Left button completes the capture, every other button cancels.
    if button_code != BTN_LEFT {
        cancel_capture_session(state);
        return;
    }
    finish_capture(state);
}

fn finish_capture<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    let Some(mut session) = state.capture_session.take() else {
        return;
    };
    let area = session.selection();
    let last_position = session.current;

    // Teleport the pointer to the drag end as part of leaving the session,
    // before anything else can observe the frozen-position residue.
    state.pointer.set_location(last_position);

    match area {
        Some(area) => finish_capture_inner(state, &mut session, area),
        None => info!("Screenshot capture cancelled: empty selection"),
    }
}

fn finish_capture_inner<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    session: &mut CaptureSession,
    area: Rectangle<f64, Logical>,
) {
    let Some(snapshot) = session.snapshot.take() else {
        warn!("Screenshot capture session has no snapshot");
        return;
    };
    let captured_outputs = [CapturedOutput {
        geometry: session.output_geometry,
        size: snapshot.size,
        pixels: snapshot.pixels,
    }];
    if session.record {
        match pixel_size(area.size, snapshot.scale) {
            Ok(unused_size) => {
                match compose_desktop_area(area, snapshot.scale, &captured_outputs) {
                    Ok((first_size, first_pixels))
                        if first_size.w == unused_size.w && first_size.h == unused_size.h =>
                    {
                        start_area_recording(
                            state,
                            &session.output,
                            session.output_geometry,
                            area,
                            snapshot.scale,
                            first_pixels,
                        );
                    }
                    _ => warn!("Recording failed to start: the first frame did not compose"),
                }
            }
            Err(message) => warn!("Recording failed to start: {message}"),
        }
        return;
    }
    match compose_desktop_area(area, snapshot.scale, &captured_outputs) {
        Ok((size, pixels)) => {
            if let Err(message) = deliver_screenshot(state, size, pixels) {
                warn!("Screenshot failed: {message}");
            }
        }
        Err(message) => warn!("Screenshot failed: {message}"),
    }
}

/// Hands the captured pixels to the background encode/write worker.
///
/// Encoding and file I/O run on a worker so they cannot stall the compositor
/// loop; the clipboard is published on the loop when the bytes exist.
fn deliver_screenshot<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    size: Size<i32, Physical>,
    pixels: Vec<u8>,
) -> Result<(), String> {
    let directory = screenshot_directory()?;
    let path = directory.join(format!(
        "Veshell Screenshot {}",
        chrono::Local::now().format("%Y-%m-%d %H-%M-%S%.3f.png")
    ));
    let sender = state.screenshot_delivery_sender.clone();
    thread::spawn(move || {
        let outcome = match encode_and_write_png(size, pixels, &path) {
            Ok(png) => ScreenshotDeliveryEvent::Completed {
                path,
                png: Arc::new(png),
            },
            Err(message) => ScreenshotDeliveryEvent::Failed { message },
        };
        if sender.send(outcome).is_err() {
            // The receiving loop is gone; nothing to deliver to.
        }
    });
    Ok(())
}

/// Result of the background PNG encode/write worker, delivered back to the
/// event loop through a calloop channel.
pub enum ScreenshotDeliveryEvent {
    Completed { path: PathBuf, png: Arc<Vec<u8>> },
    Failed { message: String },
}

/// Registers the channel that carries worker results back onto the loop.
/// Returns the worker-side sender; the receiver closes only when the state is
/// dropped.
pub fn insert_screenshot_delivery_source<BackendData: Backend + 'static>(
    loop_handle: &LoopHandle<'static, State<BackendData>>,
) -> channel::Sender<ScreenshotDeliveryEvent> {
    let (sender, receiver) = channel::channel::<ScreenshotDeliveryEvent>();
    loop_handle
        .insert_source(receiver, |event, _, state| {
            if let channel::Event::Msg(outcome) = event {
                complete_screenshot_delivery(state, outcome);
            }
        })
        .expect("Failed to init screenshot delivery channel");
    sender
}

/// Publishes a finished screenshot to the Wayland and XWayland clipboards.
///
/// The selection is advertised only now, on the event loop, so no client can
/// request pixels before they exist; reads are served lazily through
/// `State::send_selection` from the `Arc` bytes handed to the selection.
fn complete_screenshot_delivery<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    outcome: ScreenshotDeliveryEvent,
) {
    match outcome {
        ScreenshotDeliveryEvent::Completed { path, png } => {
            let mime_types = vec![PNG_MIME.to_string(), NATIVE_SCREENSHOT_MIME.to_string()];
            if let Some(xwm) = state
                .xwayland_state
                .as_mut()
                .and_then(|state| state.xwm.as_mut())
            {
                if let Err(error) =
                    xwm.new_selection(SelectionTarget::Clipboard, Some(mime_types.clone()))
                {
                    warn!(?error, "Failed to publish native screenshot to XWayland");
                }
            }
            set_data_device_selection(&state.display_handle, &state.seat, mime_types, Some(png));
            info!("Screenshot saved: {}", path.display());
        }
        ScreenshotDeliveryEvent::Failed { message } => warn!("Screenshot failed: {message}"),
    }
}

struct CapturedOutput {
    geometry: Rectangle<f64, Logical>,
    size: Size<i32, Physical>,
    pixels: Vec<u8>,
}

/// Renders the frozen desktop into capture-owned CPU storage.
///
/// The Flutter dmabuf it reads is only borrowed for the duration of this
/// synchronous render-then-readback, which completes in one dispatch on the
/// event loop thread (the existing present `gl.Finish` barrier applies).
/// Everything else the capture later sees is owned `Vec<u8>` data, never a
/// swapchain buffer that could be recycled under it.
/// Grabs the output's current desktop pixels for a shared stream: the
/// full-frame path mirrors the screenshot snapshot pipeline (capture
/// specification section 6 allows full-frame copies as the initial
/// delivery implementation).
pub fn capture_output_pixels<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    output: &Output,
) -> Result<CaptureSnapshot, String> {
    take_output_snapshot(state, output)
}

fn take_output_snapshot<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    output: &Output,
) -> Result<CaptureSnapshot, String> {
    let view_id = output
        .user_data()
        .get::<OutputViewIdWrapper>()
        .ok_or_else(|| format!("Output {} has no Flutter view", output.name()))?
        .view_id;
    let flutter_dmabuf = latest_flutter_dmabuf(state, view_id)?;
    let geometry = state
        .space
        .output_geometry(output)
        .ok_or_else(|| format!("Output {} has no geometry", output.name()))?
        .to_f64();
    let output_name = output.name();
    let game_surface_list: Vec<
        smithay::reexports::wayland_server::protocol::wl_surface::WlSurface,
    > = state
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

    let (size, pixels) = state
        .backend_data
        .with_primary_renderer_mut(|renderer| {
            let bytes = render_output_to_memory(
                renderer,
                output,
                &flutter_dmabuf,
                geometry,
                BackendData::FLIP_FLUTTER_TEXTURE,
                game_surface_list.iter().collect(),
            )?;
            orient_readback(output, bytes)
        })
        .ok_or_else(|| "No renderer is available to capture the output".to_string())??;

    Ok(CaptureSnapshot {
        size,
        scale: output.current_scale().fractional_scale(),
        pixels,
    })
}

fn compose_desktop_area(
    area: Rectangle<f64, Logical>,
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

fn pixel_size(size: Size<f64, Logical>, scale: f64) -> Result<Size<i32, Physical>, String> {
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
    rectangle: Rectangle<f64, Logical>,
    origin: Point<f64, Logical>,
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
    output_geometry: Rectangle<f64, Logical>,
    flip_flutter_texture: bool,
    game_surface_list: Vec<&smithay::reexports::wayland_server::protocol::wl_surface::WlSurface>,
) -> Result<Vec<u8>, String> {
    let mode = output
        .current_mode()
        .ok_or_else(|| format!("Output {} has no mode", output.name()))?;
    let size = mode.size.to_logical(1).to_buffer(1, Transform::Normal);
    let mut target_buffer =
        Offscreen::<GlesRenderbuffer>::create_buffer(renderer, Fourcc::Abgr8888, size)
            .map_err(|error| format!("Unable to create capture buffer: {error}"))?;
    let mut target = renderer
        .bind(&mut target_buffer)
        .map_err(|error| format!("Unable to bind capture buffer: {error}"))?;
    // The cursor is deliberately not rendered: a screenshot should not
    // contain the pointer. Game-mode surfaces stay, they are part of the
    // desktop the user sees.
    let elements = get_frame_elements_from_dmabuf(
        renderer,
        output,
        flutter_dmabuf,
        output_geometry,
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

fn encode_and_write_png(
    size: Size<i32, Physical>,
    pixels: Vec<u8>,
    path: &Path,
) -> Result<Vec<u8>, String> {
    let png = encode_png(size, pixels)
        .map_err(|error| format!("Unable to encode screenshot {}: {error}", path.display()))?;
    let file_name = path
        .file_name()
        .and_then(|name| name.to_str())
        .ok_or_else(|| format!("Invalid screenshot path {}", path.display()))?;
    let part_path = path.with_file_name(format!("{file_name}.part"));
    let result = File::create(&part_path)
        .and_then(|mut file| file.write_all(&png))
        .and_then(|()| fs::rename(&part_path, path))
        .map_err(|error| format!("Unable to write screenshot {}: {error}", path.display()));
    if result.is_err() {
        let _ = fs::remove_file(&part_path);
    }
    result.map(|()| png)
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

fn recording_directory() -> Result<PathBuf, String> {
    let path = xdg_user::videos()
        .ok()
        .flatten()
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join("Videos")))
        .ok_or_else(|| "Unable to determine the recording directory".to_string())?;
    fs::create_dir_all(&path).map_err(|error| {
        format!(
            "Unable to create recording directory {}: {error}",
            path.display()
        )
    })?;
    Ok(path)
}

/// Fixed geometry of one local recording (specification section 5.2/§9:
/// initial release never resizes a running stream).
pub struct RecordingGeometry {
    pub size: Size<i32, Physical>,
    pub fps: u32,
}

/// Frame cadence of a local recording, capped at the shared 30 FPS
/// budget (specification section 6).
const RECORDING_FPS: u32 = 30;
const RECORDING_FRAME_INTERVAL: std::time::Duration =
    std::time::Duration::from_millis(1000 / RECORDING_FPS as u64);

/// A live local recorder. The compositor loop pumps frames at the fixed
/// FPS interval; geometry changes stop the recording instead of
/// resizing it.
pub struct LiveRecording {
    recorder: crate::capture::recording::RecordingHandle,
    generation: u64,
    output: Output,
    area: Rectangle<f64, Logical>,
    output_geometry: Rectangle<f64, Logical>,
    scale: f64,
    started: std::time::Instant,
    dropped: u32,
}

impl LiveRecording {
    pub fn output_name(&self) -> String {
        self.output.name()
    }
}

/// Leaves the selection session and starts recording the selected area:
/// the first frame is the frozen, overlay-free snapshot frame; further
/// frames are live output copies at the fixed pixel geometry.
fn start_area_recording<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    output: &Output,
    output_geometry: Rectangle<f64, Logical>,
    area: Rectangle<f64, Logical>,
    scale: f64,
    first_frame: Vec<u8>,
) {
    let size = match pixel_size(area.size, scale) {
        Ok(size) => size,
        Err(message) => {
            warn!("Recording failed to start: {message}");
            return;
        }
    };
    let geometry = RecordingGeometry {
        size,
        fps: RECORDING_FPS,
    };
    let delivery = state.recording_delivery_sender.clone();
    let mut recorder = match recording::spawn_recording_worker(geometry, delivery) {
        Ok(recorder) => recorder,
        Err(message) => {
            warn!("Recording failed to start: {message}");
            return;
        }
    };
    let generation = recorder.generation();
    if !recorder.push_frame(first_frame) {
        warn!("Recording failed to start: the first frame was dropped");
        return;
    }
    let live = LiveRecording {
        recorder,
        generation,
        output: output.clone(),
        area,
        output_geometry,
        scale,
        started: std::time::Instant::now(),
        dropped: 0,
    };
    state.recording_session = Some(live);
    schedule_recording_pump(state, generation);
    info!(
        output = output.name(),
        area = ?area,
        size = ?size,
        "Recording started"
    );
}

/// Drives the fixed FPS frame pump for exactly one recording
/// generation; stale timers of finished recordings drop themselves.
fn schedule_recording_pump<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    generation: u64,
) {
    use smithay::reexports::calloop::timer::{TimeoutAction, Timer};
    let mut timer = Timer::from_duration(RECORDING_FRAME_INTERVAL);
    state
        .loop_handle
        .insert_source(timer, move |_, _, state| {
            if !state
                .recording_session
                .as_ref()
                .is_some_and(|recording| recording.generation == generation)
            {
                return TimeoutAction::Drop;
            }
            pump_recording_frame(state, generation);
            TimeoutAction::ToDuration(RECORDING_FRAME_INTERVAL)
        })
        .expect("Recording pump timer can be scheduled");
}

/// Copies the output once, crops it to the fixed area, and hands the
/// pixels to the worker. Layout, mode, or scale changes stop the
/// recording (specification section 5.1); slow encoding drops frames.
fn pump_recording_frame<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    generation: u64,
) {
    let Some(recording) = state.recording_session.as_ref() else {
        return;
    };
    if recording.generation != generation {
        return;
    }
    let output = recording.output.clone();
    let area = recording.area;
    let output_geometry = recording.output_geometry;
    let scale = recording.scale;
    let expected = state
        .space
        .output_geometry(&output)
        .map(|geometry| geometry.to_f64());
    let scale_now = output.current_scale().fractional_scale();
    if expected != Some(output_geometry) || scale_now != scale {
        stop_recording(state, "the screen layout changed during the recording");
        return;
    }

    let snapshot = match take_output_snapshot(state, &output) {
        Ok(snapshot) => snapshot,
        Err(message) => {
            debug!("Recording frame skipped: {message}");
            return;
        }
    };
    if snapshot.scale != scale {
        stop_recording(state, "the output scale changed during the recording");
        return;
    }
    let captured = [CapturedOutput {
        geometry: output_geometry,
        size: snapshot.size,
        pixels: snapshot.pixels,
    }];
    let Ok((size, pixels)) = compose_desktop_area(area, snapshot.scale, &captured) else {
        return;
    };
    if let Some(recording) = state.recording_session.as_mut() {
        if !recording.recorder.push_frame(pixels) {
            recording.dropped += 1;
        }
    }
}

/// Stops the live recording; the worker finalizes asynchronously and
/// reports the final path or failure through the delivery channel.
pub fn stop_recording<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    reason: &str,
) {
    if let Some(recording) = state.recording_session.take() {
        let elapsed_ms = recording.started.elapsed().as_millis() as u64;
        let output = recording.output_name();
        recording.recorder.stop();
        info!(
            output,
            elapsed_ms,
            dropped = recording.dropped,
            reason,
            "Recording stop requested"
        );
    }
}

/// Result of a recording worker session, delivered back through a
/// calloop channel (mirror of the screenshot delivery).
pub fn insert_recording_delivery_source<BackendData: Backend + 'static>(
    loop_handle: &LoopHandle<'static, State<BackendData>>,
) -> channel::Sender<recording::RecordingEvent> {
    let (sender, receiver) = channel::channel::<recording::RecordingEvent>();
    loop_handle
        .insert_source(receiver, |event, _, state| {
            if let channel::Event::Msg(receipt) = event {
                handle_recording_event(state, receipt);
            }
        })
        .expect("Failed to init recording delivery channel");
    sender
}

fn handle_recording_event<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    outcome: recording::RecordingEvent,
) {
    let _ = state;
    match outcome {
        recording::RecordingEvent::Completed {
            path,
            frames,
            dropped,
            elapsed_ms,
        } => {
            info!(
                path = %path.display(),
                frames,
                dropped,
                elapsed_ms,
                "Recording saved"
            );
        }
        recording::RecordingEvent::Failed { message, partial } => match partial {
            Some(partial) => warn!(
                partial = %partial.display(),
                "Failed: {message}"
            ),
            None => warn!("{message}"),
        },
    }
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
    fn screenshot_png_is_encoded_for_clipboard_and_file() {
        let encoded = encode_png((1, 1).into(), vec![1, 2, 3, 255]).unwrap();

        assert_eq!(&encoded[..8], b"\x89PNG\r\n\x1a\n");
    }

    #[test]
    fn encode_and_write_png_renames_part_file_atomically() {
        let directory =
            std::env::temp_dir().join(format!("veshell-capture-test-{}", std::process::id()));
        fs::create_dir_all(&directory).unwrap();
        let path = directory.join("shot.png");

        let png = encode_and_write_png((1, 1).into(), vec![1, 2, 3, 255], &path).unwrap();

        assert_eq!(fs::read(&path).unwrap(), png);
        assert!(!directory.join("shot.png.part").exists());
        let _ = fs::remove_dir_all(directory);
    }

    #[test]
    fn encode_and_write_png_leaves_no_part_file_when_directory_is_missing() {
        let directory =
            std::env::temp_dir().join(format!("veshell-capture-missing-{}", std::process::id()));
        let path = directory.join("shot.png");

        assert!(encode_and_write_png((1, 1).into(), vec![1, 2, 3, 255], &path).is_err());

        assert!(!path.exists());
        assert!(!directory.join("shot.png.part").exists());
        let _ = fs::remove_dir_all(directory);
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
    fn selection_rectangle_normalizes_drag_orientation() {
        let session = CaptureSession {
            output: test_output(),
            output_geometry: Rectangle::new((0., 0.).into(), (100., 100.).into()),
            start: Some((80., 90.).into()),
            current: (10., 20.).into(),
            snapshot: None,
            record: false,
        };

        let rect = session.selection().unwrap();

        assert_eq!(rect.loc, (10., 20.).into());
        assert_eq!(rect.size, (70., 70.).into());
    }

    #[test]
    fn click_without_drag_selects_nothing() {
        let session = CaptureSession {
            output: test_output(),
            output_geometry: Rectangle::new((0., 0.).into(), (100., 100.).into()),
            start: Some((10., 10.).into()),
            current: (10., 10.).into(),
            snapshot: None,
            record: false,
        };

        assert!(session.selection().is_none());
    }

    fn test_output() -> Output {
        Output::new(
            "test".into(),
            smithay::output::PhysicalProperties {
                size: (100, 100).into(),
                subpixel: smithay::output::Subpixel::Unknown,
                make: String::new(),
                model: String::new(),
                serial_number: String::new(),
            },
        )
    }
}
