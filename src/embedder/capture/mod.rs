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
use smithay::backend::renderer::element::memory::MemoryRenderBufferRenderElement;
use smithay::backend::renderer::element::solid::SolidColorRenderElement;
use smithay::backend::renderer::element::surface::render_elements_from_surface_tree;
use smithay::backend::renderer::element::Kind;
use smithay::backend::renderer::gles::{GlesRenderbuffer, GlesRenderer};
use smithay::backend::renderer::utils::with_renderer_surface_state;
use smithay::backend::renderer::{Bind, ExportMem, ImportAll, ImportMem, Offscreen};
use smithay::output::Output;
use smithay::reexports::calloop::{channel, LoopHandle};
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::reexports::wayland_server::Resource;
use smithay::utils::{Buffer, Logical, Physical, Point, Rectangle, Scale, Size, Transform};
use smithay::wayland::selection::data_device::set_data_device_selection;
use smithay::wayland::selection::SelectionTarget;
use tracing::{debug, info, warn};

use crate::backend::render::get_frame_elements_from_dmabuf;
use crate::flutter_engine::view::OutputViewIdWrapper;
use crate::meta_window_state::meta_window::MetaWindow;
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
    if session.record {
        let snapshot_scale = snapshot.scale;
        match compose_recording_frame(
            area,
            snapshot_scale,
            session.output_geometry,
            snapshot,
            None,
        ) {
            Ok((size, first_pixels)) => start_area_recording(
                state,
                &session.output,
                session.output_geometry,
                area,
                snapshot_scale,
                size,
                first_pixels,
            ),
            Err(message) => warn!("Recording failed to start: {message}"),
        }
        return;
    }
    let captured_outputs = [CapturedOutput {
        geometry: session.output_geometry,
        size: snapshot.size,
        pixels: snapshot.pixels,
    }];
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
        let outcome = match encode_and_write_png(size, &pixels, &path) {
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

// Element set for the isolated window capture render (a macro invocation: no rustdoc).
smithay::backend::renderer::element::render_elements! {
    pub WindowCaptureElements<R> where
        R: ImportAll + ImportMem;
    Memory=MemoryRenderBufferRenderElement<R>,
    Surface=smithay::backend::renderer::element::surface::WaylandSurfaceRenderElement<R>,
    Solid=SolidColorRenderElement
}

/// The render scale of a window's isolated viewport: the scale the client
/// actually renders with, never an output's scale (the shell-view's own
/// relationship, spec 5.3).
pub(crate) fn window_render_scale(meta_window: &MetaWindow) -> f64 {
    meta_window.scale_ratio.max(1.0)
}

/// The logical viewport a window share composes into, in the window
/// surface's own coordinate space: the shell-view's content-area geometry
/// when it exists (which is what the on-screen presentation also shows,
/// negative origins included), otherwise the surface's natural logical
/// size anchoring the viewport at its top-left corner.
pub(crate) fn window_viewport(
    meta_window: &MetaWindow,
    surface: Option<&WlSurface>,
) -> Option<Rectangle<f64, Logical>> {
    if let Some(geometry) = meta_window.geometry.as_ref() {
        return Some(Rectangle::new(
            (geometry.0.loc.x as f64, geometry.0.loc.y as f64).into(),
            (geometry.0.size.w as f64, geometry.0.size.h as f64).into(),
        ));
    }
    let logical = surface.and_then(|surface| {
        with_renderer_surface_state(surface, |state| state.surface_size()).unwrap_or(None)
    })?;
    Some(Rectangle::new(
        (0., 0.).into(),
        (logical.w as f64, logical.h as f64).into(),
    ))
}

/// Popup layers of one window in stable stacking order, each with the
/// popup surface's origin relative to the window surface's top-left
/// corner (surface-local logical coordinates) and the popup's own render
/// scale.
///
/// Ownership is explicit through the MetaPopup registry, where each
/// popup's parent is the root meta window id it was positioned under. A
/// surface the registry cannot bind to this window is omitted entirely —
/// never guessed by title, pid, or geometry. Stacking follows surface id
/// order, which is commit order, so the order is stable across frames.
pub(crate) fn owned_popup_layers(
    meta_window: &MetaWindow,
    state: &crate::state::State<impl Backend>,
) -> Vec<(u64, WlSurface, Point<f64, Logical>, f64)> {
    let mut popups: Vec<_> = state
        .meta_window_state
        .meta_popups
        .values()
        .filter(|popup| popup.parent == meta_window.id)
        .filter_map(|popup| {
            let surface = state.surfaces.get(&popup.surface_id)?.clone();
            // The shell view places a popup surface's top-left corner at
            // `position - content-area top-left`, relative to the window's
            // own surface origin (see MetaPopupWidget).
            let origin = match popup.geometry.as_ref() {
                Some(geometry) => Point::<f64, Logical>::from((
                    (popup.position.0.x - geometry.0.loc.x) as f64,
                    (popup.position.0.y - geometry.0.loc.y) as f64,
                )),
                None => Point::<f64, Logical>::from((
                    popup.position.0.x as f64,
                    popup.position.0.y as f64,
                )),
            };
            Some((
                popup.surface_id,
                surface,
                origin,
                popup.scale_ratio.max(1.0),
            ))
        })
        .collect();
    popups.sort_by_key(|(surface_id, _, _, _)| *surface_id);
    popups
        .into_iter()
        .map(|(id, surface, origin, scale)| (id, surface, origin, scale))
        .collect()
}

/// Renders one client surface's whole tree (subsurfaces included) at the
/// given render scale into capture-owned CPU storage, starting at the
/// surface's own origin. The offscreen readback is synchronous on the
/// loop exactly like the output snapshot path.
fn render_surface_layer_pixels(
    renderer: &mut GlesRenderer,
    surface: &WlSurface,
    scale: f64,
) -> Result<(Size<i32, Logical>, Vec<u8>), String> {
    let logical_size = with_renderer_surface_state(surface, |state| state.surface_size())
        .unwrap_or(None)
        .ok_or_else(|| "Surface has no rendered content yet".to_string())?;
    let canvas_physical =
        Size::<f64, Logical>::from((logical_size.w as f64, logical_size.h as f64))
            .to_physical(Scale { x: scale, y: scale })
            .to_i32_round();
    let canvas_buffer = Size::<i32, Buffer>::from((canvas_physical.w, canvas_physical.h));
    let mut target_buffer =
        Offscreen::<GlesRenderbuffer>::create_buffer(renderer, Fourcc::Abgr8888, canvas_buffer)
            .map_err(|error| format!("Unable to create capture buffer: {error}"))?;
    let mut target = renderer
        .bind(&mut target_buffer)
        .map_err(|error| format!("Unable to bind capture buffer: {error}"))?;
    let elements: Vec<WindowCaptureElements<GlesRenderer>> =
        render_elements_from_surface_tree(renderer, surface, (0, 0), scale, 1.0, Kind::Unspecified);
    let mut tracker = OutputDamageTracker::new(canvas_physical, scale, Transform::Normal);
    tracker
        .render_output(renderer, &mut target, 0, &elements, [0.0, 0.0, 0.0, 1.0])
        .map_err(|error| format!("Unable to render capture: {error}"))?;
    let mapping = renderer
        .copy_framebuffer(
            &target,
            Rectangle::from_size(canvas_buffer),
            Fourcc::Abgr8888,
        )
        .map_err(|error| format!("Unable to read capture buffer: {error}"))?;
    let pixels = renderer
        .map_texture(&mapping)
        .map(|pixels| pixels.to_vec())
        .map_err(|error| format!("Unable to map capture buffer: {error}"))?;
    Ok(((canvas_physical.w, canvas_physical.h).into(), pixels))
}

/// Renders the live client pixels of one MetaWindow viewport into
/// capture-owned CPU storage.
///
/// All renders run synchronously on the event loop with the same GPU
/// completion semantics as the output snapshot path (gles renderer
/// commands are serialized here and complete before readback), and the
/// results are owned `Vec<u8>` copies: nothing later reads a client
/// buffer.
pub fn capture_window_pixels<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    meta_window_id: &str,
) -> Result<(Size<i32, Physical>, Vec<u8>), String> {
    let (meta_window, root_surface) = {
        let meta_window = state
            .meta_window_state
            .meta_windows
            .get(meta_window_id)
            .cloned()
            .ok_or_else(|| format!("Shared window {meta_window_id} no longer exists"))?;
        if !meta_window.mapped {
            return Err(format!("Shared window {meta_window_id} is unmapped"));
        }
        let surface = state
            .surfaces
            .get(&meta_window.surface_id)
            .cloned()
            .ok_or_else(|| format!("Shared window {meta_window_id} has no live surface"))?;
        (meta_window, surface)
    };

    let scale = window_render_scale(&meta_window);
    let viewport = window_viewport(&meta_window, Some(&root_surface))
        .ok_or_else(|| "Shared window has no rendered content yet".to_string())?;

    // Occlusion and desktop position never matter for a window source:
    // only this client's own pixels are composed (spec 5.3).
    let mut ordered: Vec<CapturedWindowLayer> = Vec::new();
    let popup_layers = owned_popup_layers(&meta_window, state);

    state
        .backend_data
        .with_primary_renderer_mut(|renderer| -> Result<(), String> {
            let (buffer_size, pixels) =
                render_surface_layer_pixels(renderer, &root_surface, scale)?;
            ordered.push(CapturedWindowLayer {
                order: 1,
                origin_in_viewport: Point::<f64, Logical>::from((-viewport.loc.x, -viewport.loc.y)),
                buffer_size: Size::from((buffer_size.w, buffer_size.h)),
                pixels,
                own_scale: scale,
            });
            for (popup_order, (surface_id, popup_surface, origin, popup_scale)) in
                popup_layers.iter().enumerate()
            {
                let _ = surface_id;
                if let Ok((buffer_size, pixels)) =
                    render_surface_layer_pixels(renderer, popup_surface, *popup_scale)
                {
                    ordered.push(CapturedWindowLayer {
                        order: popup_order + 2,
                        origin_in_viewport: Point::<f64, Logical>::from((
                            origin.x - viewport.loc.x,
                            origin.y - viewport.loc.y,
                        )),
                        buffer_size: Size::from((buffer_size.w, buffer_size.h)),
                        pixels,
                        own_scale: *popup_scale,
                    });
                }
            }
            Ok(())
        })
        .ok_or_else(|| "No renderer is available to capture the window".to_string())??;
    ordered.sort_by_key(|layer| layer.order);

    compose_window_pixels(viewport, scale, &ordered)
}

/// Captures a whole output natively for a portal Screenshot request
/// (spec 8.4): the same frozen-desktop snapshot pipeline as the hotkey
/// flow, composed at full output geometry, with no selection and no
/// pointer involvement.
pub fn capture_full_output<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    output: &Output,
) -> Result<(Size<i32, Physical>, Vec<u8>), String> {
    let snapshot = take_output_snapshot(state, output)?;
    let geometry = state
        .space
        .output_geometry(output)
        .ok_or_else(|| format!("Output {} has no geometry", output.name()))?
        .to_f64();
    let captured = [CapturedOutput {
        geometry,
        size: snapshot.size,
        pixels: snapshot.pixels,
    }];
    compose_desktop_area(geometry, snapshot.scale, &captured)
}

/// A portal request's pixels frozen before the prompt dialog rendered
/// over the desktop (spec 8.4): the response frame for screenshots, and
/// the sample source for color picks, capped and evicted by the composit
/// or loop.
#[derive(Debug)]
pub struct PendingPortalPixels {
    /// The composed output's pixel size.
    pub size: Size<i32, Physical>,
    pub pixels: Vec<u8>,
    /// The logical full-output area the pixels were composed from.
    pub geometry: Rectangle<f64, Logical>,
    /// The pointer location at request time (PickColor target).
    pub pointer: Point<f64, Logical>,
}

/// Renders and stores the pre-prompt desktop frame for a portal
/// request.
pub fn take_portal_pending_snapshot<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    output: &Output,
    pointer: Point<f64, Logical>,
) -> Result<PendingPortalPixels, String> {
    let snapshot = take_output_snapshot(state, output)?;
    let geometry = state
        .space
        .output_geometry(output)
        .ok_or_else(|| format!("Output {} has no geometry", output.name()))?
        .to_f64();
    let captured = [CapturedOutput {
        geometry,
        size: snapshot.size,
        pixels: snapshot.pixels,
    }];
    let (size, pixels) = compose_desktop_area(geometry, snapshot.scale, &captured)?;
    Ok(PendingPortalPixels {
        size,
        pixels,
        geometry,
        pointer,
    })
}

/// Samples one pixel from a held pre-prompt snapshot (PickColor):
/// sRGB floats in [0, 1]. The readback byte order is R,G,B,A.
pub fn sample_pending_pixel(
    pending: &PendingPortalPixels,
    location: Point<f64, Logical>,
) -> Result<(f64, f64, f64), String> {
    let rel_x =
        ((location.x - pending.geometry.loc.x) / pending.geometry.size.w.max(1e-6)).clamp(0.0, 1.0);
    let rel_y =
        ((location.y - pending.geometry.loc.y) / pending.geometry.size.h.max(1e-6)).clamp(0.0, 1.0);
    let px_x = ((rel_x * pending.size.w as f64) as usize).clamp(0, pending.size.w as usize - 1);
    let px_y = ((rel_y * pending.size.h as f64) as usize).clamp(0, pending.size.h as usize - 1);
    let offset = (px_y * pending.size.w as usize + px_x) * 4;
    let pixel = pending
        .pixels
        .get(offset..offset + 4)
        .ok_or_else(|| "The sampled pixel index is out of range".to_string())?;
    Ok((
        pixel[0] as f64 / 255.0,
        pixel[1] as f64 / 255.0,
        pixel[2] as f64 / 255.0,
    ))
}

/// Grabs one pixel from the output for a portal PickColor request:
/// returns sRGB floats in [0, 1] at the pointer's location. The
/// readback byte order matches the desktop readback (R,G,B,A), so the
/// channels are already in RGB order.
pub fn sample_output_pixel<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    output: &Output,
    location: Point<f64, Logical>,
) -> Result<(f64, f64, f64), String> {
    let snapshot = take_output_snapshot(state, output)?;
    let geometry = state
        .space
        .output_geometry(output)
        .ok_or_else(|| format!("Output {} has no geometry", output.name()))?
        .to_f64();
    let rel_x = ((location.x - geometry.loc.x) / geometry.size.w.max(1e-6)).clamp(0.0, 1.0);
    let rel_y = ((location.y - geometry.loc.y) / geometry.size.h.max(1e-6)).clamp(0.0, 1.0);
    let px_x = ((rel_x * snapshot.size.w as f64) as usize).clamp(0, snapshot.size.w as usize - 1);
    let px_y = ((rel_y * snapshot.size.h as f64) as usize).clamp(0, snapshot.size.h as usize - 1);
    let offset = (px_y * snapshot.size.w as usize + px_x) * 4;
    let bytes = snapshot.pixels.as_slice();
    let pixel = bytes
        .get(offset..offset + 4)
        .ok_or_else(|| "The sampled pixel index is out of range".to_string())?;
    Ok((
        pixel[0] as f64 / 255.0,
        pixel[1] as f64 / 255.0,
        pixel[2] as f64 / 255.0,
    ))
}

/// Encodes one PNG for a portal Screenshot request into the shared
/// screenshot directory: the same atomic part-file rename flow as the
/// hotkey path so portal consumers receive a fully written file.
pub fn encode_portal_png(size: Size<i32, Physical>, pixels: &[u8]) -> Result<PathBuf, String> {
    let directory = screenshot_directory()?;
    let path = directory.join(format!(
        "Veshell Screenshot {}",
        chrono::Local::now().format("%Y-%m-%d %H-%M-%S%.3f.png")
    ));
    encode_and_write_png(size, pixels, &path)?;
    Ok(path)
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

/// Composes the isolated window viewport from pre-rendered, capture-owned
/// layers (pure, unit-testable): an opaque black background, the window's
/// own pixels, then owned popups in stable stacking order, each clipped
/// to the viewport. Anything the caller does not hand in — another
/// window, a shell panel, a decoration — can never appear, which is what
/// keeps an obscured window share free of unrelated content.
fn compose_window_pixels(
    viewport: Rectangle<f64, Logical>,
    viewport_scale: f64,
    layers: &[CapturedWindowLayer],
) -> Result<(Size<i32, Physical>, Vec<u8>), String> {
    let size = pixel_size(viewport.size, viewport_scale)?;
    let mut pixels = vec![0; pixel_len(size)?];
    for pixel in pixels.chunks_exact_mut(4) {
        pixel[3] = 255;
    }

    let mut ordered: Vec<&CapturedWindowLayer> = layers.iter().collect();
    ordered.sort_by(|a, b| a.order.cmp(&b.order));
    for layer in ordered {
        if !layer.origin_in_viewport.x.is_finite() || !layer.origin_in_viewport.y.is_finite() {
            return Err("Capture bounds are invalid".to_string());
        }
        // Each layer renders at its own scale; map its pixels into the
        // viewport's scale so a popup at a different client scale would
        // still align (same relationship the shell view shows).
        let own = layer.own_scale.max(1e-6);
        let destination_size = Size::<i32, Physical>::from((
            (layer.buffer_size.w as f64 * viewport_scale / own).floor() as i32,
            (layer.buffer_size.h as f64 * viewport_scale / own).floor() as i32,
        ));
        let destination_loc = Point::<i32, Physical>::from((
            (layer.origin_in_viewport.x * viewport_scale).round() as i32,
            (layer.origin_in_viewport.y * viewport_scale).round() as i32,
        ));
        let destination = Rectangle::new(destination_loc, destination_size);
        blit_clipped(
            &mut pixels,
            size,
            &layer.pixels,
            layer.buffer_size,
            destination,
        )?;
    }

    Ok((size, pixels))
}

/// A rendered capture layer for the pure composition step: one surface
/// tree's pixels at its own render scale, already positioned relative to
/// the viewport's top-left corner.
#[derive(Clone)]
pub(crate) struct CapturedWindowLayer {
    /// Stable stacking order; 1 is the window itself, 2.. are popups.
    pub(crate) order: usize,
    /// Where the layer's buffer top-left sits, in viewport-relative
    /// logical coordinates (may be negative or beyond the viewport).
    pub(crate) origin_in_viewport: Point<f64, Logical>,
    pub(crate) buffer_size: Size<i32, Physical>,
    pub(crate) pixels: Vec<u8>,
    /// The layer's own logical-to-physical render scale.
    pub(crate) own_scale: f64,
}

/// Copies a source image into a destination with hard clipping on every
/// side: source and destination regions outside either buffer are cut
/// (the viewport's popup clip), the rest copies pixel-exact.
fn blit_clipped(
    destination_pixels: &mut [u8],
    destination_size: Size<i32, Physical>,
    source_pixels: &[u8],
    source_size: Size<i32, Physical>,
    destination: Rectangle<i32, Physical>,
) -> Result<(), String> {
    // The visible window of both buffers after clipping.
    let left = destination.loc.x.max(0);
    let top = destination.loc.y.max(0);
    let right = (destination.loc.x + destination.size.w).min(destination_size.w);
    let bottom = (destination.loc.y + destination.size.h).min(destination_size.h);
    if right <= left || bottom <= top {
        return Ok(());
    }
    let destination_width = destination_size.w as usize;
    for destination_y in top..bottom {
        let source_y = destination_y - destination.loc.y;
        if source_y < 0 || source_y >= source_size.h {
            continue;
        }
        for destination_x in left..right {
            let source_x = destination_x - destination.loc.x;
            if source_x < 0 || source_x >= source_size.w {
                continue;
            }
            let source_offset =
                (source_y as usize * source_size.w as usize + source_x as usize) * 4;
            let destination_offset =
                (destination_y as usize * destination_width + destination_x as usize) * 4;
            destination_pixels[destination_offset..destination_offset + 4]
                .copy_from_slice(&source_pixels[source_offset..source_offset + 4]);
        }
    }
    Ok(())
}

pub(crate) fn pixel_size(
    size: Size<f64, Logical>,
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

    // No rotation: the mapped framebuffer is already in the output's
    // logical orientation, so skip the allocation and per-pixel remap.
    if transform == Transform::Normal {
        return Ok((source_size, readback_pixels));
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
    pixels: &[u8],
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

fn encode_png(size: Size<i32, Physical>, pixels: &[u8]) -> Result<Vec<u8>, png::EncodingError> {
    let mut png = Vec::new();
    let mut encoder = png::Encoder::new(&mut png, size.w as u32, size.h as u32);
    encoder.set_color(png::ColorType::Rgba);
    encoder.set_depth(png::BitDepth::Eight);
    encoder
        .write_header()
        .and_then(|mut writer| writer.write_image_data(pixels))?;
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
/// The idle heartbeat keeps a static scene refreshing while presents
/// carry the live-motion cadence (damage-coupled delivery per spec 6).
const RECORDING_HEARTBEAT_INTERVAL: std::time::Duration = std::time::Duration::from_millis(500);

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
    size: Size<i32, Physical>,
    started: std::time::Instant,
    last_frame: Option<std::time::Instant>,
    dropped: u32,
}

impl LiveRecording {
    pub fn output_name(&self) -> String {
        self.output.name()
    }

    /// The trusted indicator data: the recorded rectangle outline plus
    /// the chip rectangle with the elapsed seconds, anchored to the
    /// rectangle's bottom-right corner. Recorded frames never contain
    /// either: the capture render path draws no overlay elements, so
    /// the indicator may sit on the shared desktop without reaching the
    /// stream.
    pub fn chip_data(&self) -> RecordingChipData {
        RecordingChipData {
            outline: self.area,
            chip: recording_chip_rect(self.area, self.output_geometry),
            seconds: self.started.elapsed().as_secs(),
        }
    }
}

/// Native recording indicator geometry/content for a render pass.
pub struct RecordingChipData {
    /// The recorded rectangle, drawn with a visible outline and a
    /// dimmed desktop outside it.
    pub outline: Rectangle<f64, Logical>,
    pub chip: Rectangle<f64, Logical>,
    pub seconds: u64,
}

/// Chip metrics in logical units.
pub(crate) const RECORDING_CHIP_WIDTH: f64 = 84.0;
pub(crate) const RECORDING_CHIP_HEIGHT: f64 = 26.0;

/// The chip sits inside the recorded rectangle's bottom-right corner; a
/// selection too small to contain it falls back to just above the
/// rectangle's right edge, where it remains visibly attached.
fn recording_chip_rect(
    area: Rectangle<f64, Logical>,
    output_geometry: Rectangle<f64, Logical>,
) -> Rectangle<f64, Logical> {
    let inset = 6.0;
    if area.size.w >= RECORDING_CHIP_WIDTH + inset && area.size.h >= RECORDING_CHIP_HEIGHT + inset {
        let origin = (
            area.loc.x + area.size.w - inset - RECORDING_CHIP_WIDTH,
            area.loc.y + area.size.h - inset - RECORDING_CHIP_HEIGHT,
        );
        Rectangle::new(
            origin.into(),
            (RECORDING_CHIP_WIDTH, RECORDING_CHIP_HEIGHT).into(),
        )
    } else {
        let origin = (
            (area.loc.x + area.size.w - RECORDING_CHIP_WIDTH).max(output_geometry.loc.x),
            (area.loc.y - RECORDING_CHIP_HEIGHT - 6.0).max(output_geometry.loc.y),
        );
        Rectangle::new(
            origin.into(),
            (RECORDING_CHIP_WIDTH, RECORDING_CHIP_HEIGHT).into(),
        )
    }
}

/// Leaves the selection session and starts recording the selected area:
/// the first frame is the frozen, overlay-free snapshot frame; further
/// frames are live output copies at the fixed pixel geometry. The
/// recorded pixel size is even in both axes: VP8's I420 contract rejects
/// odd-height chroma, and the first real run stalled exactly there.
fn start_area_recording<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    output: &Output,
    output_geometry: Rectangle<f64, Logical>,
    area: Rectangle<f64, Logical>,
    scale: f64,
    selected_size: Size<i32, Physical>,
    first_frame: Vec<u8>,
) {
    let size = even_size(selected_size);
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
        size,
        started: std::time::Instant::now(),
        last_frame: None,
        dropped: 0,
    };
    state.recording_session = Some(live);
    schedule_recording_heartbeat(state, generation);
    info!(
        output = output.name(),
        area = ?area,
        size = ?size,
        "Recording started"
    );
}

/// Composes the fixed area at the selection scale, in the recording's
/// even pixel size: frames that fail to compose or do not match the
/// fixed geometry stop the recording immediately instead of feeding a
/// doomed pipeline.
fn compose_recording_frame(
    area: Rectangle<f64, Logical>,
    scale: f64,
    output_geometry: Rectangle<f64, Logical>,
    snapshot: CaptureSnapshot,
    geometry_size: Option<Size<i32, Physical>>,
) -> Result<(Size<i32, Physical>, Vec<u8>), String> {
    let captured = [CapturedOutput {
        geometry: output_geometry,
        size: snapshot.size,
        pixels: snapshot.pixels,
    }];
    let (size, pixels) = compose_desktop_area(area, snapshot.scale, &captured)?;
    let even = even_size(size);
    let pixels = crop_to_size(pixels, size, even);
    if let Some(expected) = geometry_size {
        if even != expected {
            return Err(format!("the frame is {even:?}, expected {expected:?}"));
        }
    }
    Ok((even, pixels))
}

/// Rounds a pixel size down to even in both axes.
fn even_size(size: Size<i32, Physical>) -> Size<i32, Physical> {
    (size.w - (size.w & 1), size.h - (size.h & 1)).into()
}

/// Crops the pixel buffer from the top-left corner to the given size
/// (the even rounding never grows a frame).
fn crop_to_size(
    pixels: Vec<u8>,
    size: Size<i32, Physical>,
    target: Size<i32, Physical>,
) -> Vec<u8> {
    if size == target {
        return pixels;
    }
    let source_width = size.w as usize;
    let mut cropped = vec![0u8; (target.w as usize) * (target.h as usize) * 4];
    for row in 0..target.h as usize {
        let source_start = row * source_width * 4;
        let source_end = source_start + target.w as usize * 4;
        let destination_start = row * target.w as usize * 4;
        cropped[destination_start..destination_start + target.w as usize * 4]
            .copy_from_slice(&pixels[source_start..source_end]);
    }
    cropped
}

/// Keeps a static desktop refreshing at the idle heartbeat rate; live
/// motion damage arrives through the presented-frame hook instead, both
/// capped by the same FPS budget (spec section 6; the unconditional
/// 30 Hz loop render this replaces stutters the desktop).
fn schedule_recording_heartbeat<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    generation: u64,
) {
    use smithay::reexports::calloop::timer::{TimeoutAction, Timer};
    let mut timer = Timer::from_duration(RECORDING_HEARTBEAT_INTERVAL);
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
            deliver_recording_frame(state, generation);
            TimeoutAction::ToDuration(RECORDING_HEARTBEAT_INTERVAL)
        })
        .expect("Recording heartbeat timer can be scheduled");
}

/// The presented Flutter frame is fresh damage for exactly one output:
/// the recording on that output gets one copy per present, throttled to
/// the 30 FPS budget by its own last-frame timestamp.
pub fn on_view_frame_presented_for_recording<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    view_id: i64,
) {
    let Some((output_name, generation)) = state.recording_session.as_ref().and_then(|recording| {
        state
            .space
            .outputs()
            .find_map(|output| {
                output
                    .user_data()
                    .get::<crate::flutter_engine::view::OutputViewIdWrapper>()
                    .filter(|wrapper| wrapper.view_id == view_id)
                    .map(|_| output.name())
            })
            .filter(|name| *name == recording.output_name())
            .map(|name| (name, recording.generation))
    }) else {
        return;
    };
    let due = state.recording_session.as_ref().is_some_and(|recording| {
        recording.last_frame.is_none_or(|last| {
            std::time::Instant::now().duration_since(last) >= RECORDING_FRAME_INTERVAL
        })
    });
    if due {
        state.recording_session.as_mut().map(|recording| {
            recording.last_frame = Some(std::time::Instant::now());
        });
        deliver_recording_frame(state, generation);
    }
}

/// Copies the output once, crops it to the fixed area, and hands the
/// pixels to the worker. Layout, mode, or scale changes stop the
/// recording (specification section 5.1); slow encoding drops frames
/// loop-side, and the worker's own watchdog reports a stalled encoder
/// through the delivery channel.
fn deliver_recording_frame<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    generation: u64,
) {
    let Some(recording) = state.recording_session.as_mut() else {
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
    let frame = compose_recording_frame(
        area,
        scale,
        output_geometry,
        snapshot,
        state
            .recording_session
            .as_ref()
            .map(|recording| recording.size),
    );
    match frame {
        Ok((_, pixels)) => {
            if let Some(recording) = state.recording_session.as_mut() {
                if !recording.recorder.push_frame(pixels) {
                    recording.dropped += 1;
                }
            }
        }
        Err(reason) => stop_recording(state, &reason),
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
    // A worker failure can arrive while the session is still live (the
    // encoder died before any stop): release the loop-side session so
    // the heartbeat, the presented-frame hook, and the capture freeze
    // do not keep running against a dead worker. A normal stop already
    // took the session, so its final event matches nothing.
    if state
        .recording_session
        .as_ref()
        .is_some_and(|recording| recording.generation == outcome.generation())
    {
        state.recording_session.take();
    }
    match outcome {
        recording::RecordingEvent::Completed {
            path,
            frames,
            dropped,
            elapsed_ms,
            ..
        } => {
            info!(
                path = %path.display(),
                frames,
                dropped,
                elapsed_ms,
                "Recording saved"
            );
        }
        recording::RecordingEvent::Failed {
            message, partial, ..
        } => match partial {
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

    fn solid_layer(
        order: usize,
        origin: (f64, f64),
        size: (i32, i32),
        color: [u8; 4],
    ) -> CapturedWindowLayer {
        CapturedWindowLayer {
            order,
            origin_in_viewport: origin.into(),
            buffer_size: size.into(),
            pixels: color.repeat((size.0 * size.1) as usize),
            own_scale: 1.0,
        }
    }

    const RED: [u8; 4] = [1, 2, 3, 255];
    const GREEN: [u8; 4] = [0, 255, 0, 255];

    // The isolated composition is additive over what the caller hands
    // in: only the passed layers may appear, the viewport origin maps to
    // the window's content area, and popups clip to the viewport bounds
    // (spec 5.3 isolation and popup clip).
    #[test]
    fn window_share_composes_window_and_clips_popups_to_the_viewport() {
        let viewport = Rectangle::new((0., 0.).into(), (4., 2.).into());
        let window = solid_layer(1, (0., 0.), (3, 2), RED);
        let popup = solid_layer(2, (2., 0.), (2, 1), GREEN);

        let (size, pixels) = compose_window_pixels(viewport, 1.0, &[window, popup]).unwrap();

        assert_eq!(size, (4, 2).into());
        let pixel = |x: i32, y: i32| {
            let offset = ((y * size.w + x) * 4) as usize;
            let mut p = [0u8; 4];
            p.copy_from_slice(&pixels[offset..offset + 4]);
            p
        };
        // Window pixels fill the top row up to the popup overlay.
        assert_eq!(pixel(0, 0), RED);
        assert_eq!(pixel(2, 0), GREEN, "the popup paints over the window");
        assert_eq!(pixel(1, 1), RED);
        // Anything outside every layer is opaque black, never another
        // window's or the desktop's pixels.
        let mut blacked = vec![0u8; 4];
        blacked.copy_from_slice(&pixel(3, 1));
        assert_eq!(blacked, [0, 0, 0, 255]);
    }

    // A popup hanging outside the viewport (negative offset, menus
    // opening upward) contributes only its intersecting part.
    #[test]
    fn window_share_clips_partially_outside_popups() {
        let viewport = Rectangle::new((0., 0.).into(), (2., 2.).into());
        let popup = solid_layer(2, (-1., 1.), (2, 1), GREEN);

        let (size, pixels) = compose_window_pixels(viewport, 1.0, &[popup]).unwrap();

        assert_eq!(size, (2, 2).into());
        // The popup covers viewport pixels x in [0, 1) on the last row.
        let at = |x: i32, y: i32| &pixels[((y * size.w + x) * 4) as usize..][..4];
        assert_eq!(at(0, 0), &[0, 0, 0, 255], "above the intersect is black");
        assert_eq!(at(0, 1), &GREEN);
        assert_eq!(at(1, 1), &[0, 0, 0, 255], "right of the intersect is black");
    }

    // Scaling maps each layer through its own render scale (mixed client
    // scales stay aligned like the shell view shows them).
    #[test]
    fn window_share_maps_layer_scales_into_the_viewport_scale() {
        let viewport = Rectangle::new((0., 0.).into(), (2., 1.).into());
        let mut layer = solid_layer(1, (0., 0.), (2, 1), GREEN);
        // A source rendered at scale 2 carries double pixels: the same
        // logical coverage in the scale-1 viewport.
        layer.own_scale = 2.0;
        layer.buffer_size = (4, 2).into();
        layer.pixels = GREEN.repeat(8);

        let (size, pixels) = compose_window_pixels(viewport, 1.0, &[layer]).unwrap();

        assert_eq!(size, (2, 1).into());
        assert_eq!(
            pixels,
            GREEN.repeat(2),
            "the layer lands on the full viewport"
        );
    }

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
        let encoded = encode_png((1, 1).into(), &[1, 2, 3, 255]).unwrap();

        assert_eq!(&encoded[..8], b"\x89PNG\r\n\x1a\n");
    }

    #[test]
    fn encode_and_write_png_renames_part_file_atomically() {
        let directory =
            std::env::temp_dir().join(format!("veshell-capture-test-{}", std::process::id()));
        fs::create_dir_all(&directory).unwrap();
        let path = directory.join("shot.png");

        let png = encode_and_write_png((1, 1).into(), &[1, 2, 3, 255], &path).unwrap();

        assert_eq!(fs::read(&path).unwrap(), png);
        assert!(!directory.join("shot.png.part").exists());
        let _ = fs::remove_dir_all(directory);
    }

    #[test]
    fn encode_and_write_png_leaves_no_part_file_when_directory_is_missing() {
        let directory =
            std::env::temp_dir().join(format!("veshell-capture-missing-{}", std::process::id()));
        let path = directory.join("shot.png");

        assert!(encode_and_write_png((1, 1).into(), &[1, 2, 3, 255], &path).is_err());

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

    // The framebuffer readback is R,G,B,A (Smithay maps Abgr8888 to
    // RGBA8); sampling must not swizzle, or a picked colour comes back
    // with red and blue exchanged.
    #[test]
    fn pick_color_returns_channels_in_rgb_order() {
        let pending = PendingPortalPixels {
            size: (2, 1).into(),
            pixels: vec![0x11, 0x22, 0x33, 0xff, 0x44, 0x55, 0x66, 0xff],
            geometry: Rectangle::new((0., 0.).into(), (2., 1.).into()),
            pointer: (0., 0.).into(),
        };

        let sampled = sample_pending_pixel(&pending, (0.25, 0.5).into()).unwrap();
        let quantize = |channel: u8| channel as f64 / 255.0;
        assert_eq!(sampled, (quantize(0x11), quantize(0x22), quantize(0x33)));
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
