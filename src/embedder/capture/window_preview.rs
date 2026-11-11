//! A persistent tile's last window frame: frozen for the shell's closing
//! animation, and persisted, already frosted, for its placeholder.
//!
//! Nothing is copied while the window lives. The shell-requested close is
//! captured when the request arrives, while the client still paints; any other
//! close (the application quitting, crashing or being killed) is captured when
//! its window is removed, from the last frame it committed: a client that is
//! gone can no longer change it, and the compositor's texture of it outlives
//! the client's buffer.

use std::fs::{self, DirBuilder, OpenOptions};
use std::io::Write;
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
use std::path::{Path, PathBuf};

use smithay::backend::allocator::Fourcc;
use smithay::backend::renderer::damage::OutputDamageTracker;
use smithay::backend::renderer::element::surface::{
    render_elements_from_surface_tree, WaylandSurfaceRenderElement,
};
use smithay::backend::renderer::element::texture::TextureRenderElement;
use smithay::backend::renderer::element::{Id, Kind};
use smithay::backend::renderer::gles::{GlesRenderbuffer, GlesRenderer, GlesTexture};
use smithay::backend::renderer::utils::with_renderer_surface_state;
use smithay::backend::renderer::{Bind, ExportMem, Offscreen, Renderer, Texture as _};
use smithay::reexports::wayland_server::protocol::wl_surface::WlSurface;
use smithay::utils::{Buffer, Physical, Point, Rectangle, Size, Transform};
use tracing::{debug, warn};

use super::{encode_png, window_render_scale, window_viewport};
use crate::meta_window_state::meta_window::MetaWindow;
use crate::{Backend, State};

/// Directory of the previews, under the compositor's cache directory.
pub const PREVIEW_DIRECTORY: &str = "window_previews";

/// A persistent tile's preview target: the last frame of a meta window is
/// written to [path] when that window goes away.
#[derive(Debug, Clone)]
pub struct WindowPreview {
    /// The persistent tile the preview belongs to, used to reject a stale
    /// clear from a tile that no longer displays the window.
    pub persistent_window_id: String,
    pub path: PathBuf,
    /// The frame was already written when the shell asked the window to close:
    /// what the client paints afterwards belongs to its teardown.
    pub persisted: bool,
}

/// Where [persistent_window_id]'s preview lives under [cache_directory].
pub fn preview_path(cache_directory: &Path, persistent_window_id: &str) -> PathBuf {
    cache_directory
        .join(PREVIEW_DIRECTORY)
        .join(format!("{persistent_window_id}.png"))
}

// Element set for the preview renders (a macro invocation: no rustdoc).
smithay::backend::renderer::element::render_elements! {
    PreviewElements<=GlesRenderer>;
    Surface=WaylandSurfaceRenderElement<GlesRenderer>,
    Texture=TextureRenderElement<GlesTexture>,
}

/// Copies the frame [meta_window_id] paints now into a texture of its own, for
/// the shell's closing animation, and returns that texture's id.
///
/// The client may paint its teardown, or recycle its buffer, as soon as it
/// handles the close request; the live texture would follow it. The copy is a
/// separate external texture, so nothing the client commits afterwards can
/// reach it, and a window that stays (one asking about unsaved changes) keeps
/// painting normally. The copy covers the whole surface, like the live
/// texture the shell lays out, at the client's own scale. It is released by
/// the shell (`release_texture`) or after `RETAINED_TEXTURE_LIFETIME`.
pub(crate) fn freeze_for_close<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    meta_window_id: &str,
) -> Option<i64> {
    let meta_window = state
        .meta_window_state
        .meta_windows
        .get(meta_window_id)
        .cloned()?;
    let surface = state.surfaces.get(&meta_window.surface_id).cloned()?;
    let logical =
        with_renderer_surface_state(&surface, |surface| surface.surface_size()).flatten()?;
    // An integer scale keeps the subsurfaces on whole pixels; the shell
    // stretches the texture over the surface's rect either way.
    let scale = window_render_scale(&meta_window).ceil().max(1.0);
    let size = Size::<i32, Physical>::from((
        (logical.w as f64 * scale).round() as i32,
        (logical.h as f64 * scale).round() as i32,
    ));
    let frozen = state.backend_data.with_primary_renderer_mut(|renderer| {
        let elements: Vec<PreviewElements> = render_elements_from_surface_tree(
            renderer,
            &surface,
            (0, 0),
            scale,
            1.0,
            Kind::Unspecified,
        );
        render_texture(renderer, size, scale, &elements)
    })?;
    let texture = match frozen {
        Ok(texture) => texture,
        Err(error) => {
            warn!("Unable to freeze the closing frame of meta window {meta_window_id}: {error}");
            return None;
        }
    };
    let texture_id = state.get_new_texture_id();
    if let Err(error) = state
        .flutter_engine_mut()
        .register_external_texture(texture_id)
    {
        warn!("Unable to register the closing frame of meta window {meta_window_id}: {error}");
        return None;
    }
    state
        .texture_swapchains
        .entry(texture_id)
        .or_default()
        .commit(texture);
    let _ = state
        .flutter_engine_mut()
        .mark_external_texture_frame_available(texture_id);
    state.retain_textures(vec![texture_id]);
    Some(texture_id)
}

/// Writes the preview of [meta_window_id] to [path]: its last frame, cropped
/// to the window's content, averaged down and blurred to the shell's frost.
///
/// The window's surface tree is rendered when it still holds a buffer; a
/// surface that already let go of it (a client unmapping before it quits) is
/// drawn from the last texture it committed. Nothing is written for a frame
/// with nothing to show (fully transparent or one plain colour, a client
/// clearing its window as it quits): the previous preview stays.
pub(crate) fn persist_window_preview<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    meta_window_id: &str,
    path: &Path,
) {
    let Some(meta_window) = state
        .meta_window_state
        .meta_windows
        .get(meta_window_id)
        .cloned()
    else {
        return;
    };
    let surface = state.surfaces.get(&meta_window.surface_id).cloned();
    let last_texture = state
        .texture_ids_per_surface_id
        .get(&meta_window.surface_id)
        .and_then(|textures| textures.last())
        .and_then(|(id, _)| state.texture_swapchains.get(id))
        .and_then(|swapchain| swapchain.newest.clone());
    let frame = state.backend_data.with_primary_renderer_mut(|renderer| {
        render_last_frame(renderer, &meta_window, surface.as_ref(), last_texture)
    });
    let (size, pixels) = match frame {
        Some(Ok(frame)) => frame,
        Some(Err(error)) => {
            debug!("No preview for meta window {meta_window_id}: {error}");
            return;
        }
        None => return,
    };
    let Some((size, pixels)) = bake_preview(size, &pixels) else {
        debug!("Skipping an empty preview of meta window {meta_window_id}");
        return;
    };
    match write_private_png(path, size, &pixels) {
        Ok(()) => debug!(
            "Persisted the preview of meta window {meta_window_id} to {}",
            path.display()
        ),
        Err(error) => {
            warn!("Unable to persist the preview of meta window {meta_window_id}: {error}")
        }
    }
}

/// Renders the window's content (its geometry inside the surface, without
/// client-side decorations or shadow margins) at one pixel per logical pixel.
fn render_last_frame(
    renderer: &mut GlesRenderer,
    meta_window: &MetaWindow,
    surface: Option<&WlSurface>,
    last_texture: Option<GlesTexture>,
) -> Result<(Size<i32, Physical>, Vec<u8>), String> {
    let viewport = window_viewport(meta_window, surface)
        .ok_or_else(|| "the window has no viewport".to_string())?;
    let size = Size::<i32, Physical>::from((
        (viewport.size.w.round() as i32).max(1),
        (viewport.size.h.round() as i32).max(1),
    ));
    let location = Point::<i32, Physical>::from((
        (-viewport.loc.x).round() as i32,
        (-viewport.loc.y).round() as i32,
    ));

    // Scale 1: subsurfaces are positioned in logical coordinates, and a
    // fractional scale misplaces them. The preview is averaged down anyway.
    let tree: Vec<PreviewElements> = surface
        .map(|surface| {
            render_elements_from_surface_tree(
                renderer,
                surface,
                location,
                1.0,
                1.0,
                Kind::Unspecified,
            )
        })
        .unwrap_or_default();
    if !tree.is_empty() {
        let pixels = render_pixels(renderer, size, &tree)?;
        if pixels.as_chunks::<4>().0.iter().any(|pixel| pixel[3] != 0) {
            return Ok((size, pixels));
        }
    }

    let texture = last_texture.ok_or_else(|| "the window has no frame left".to_string())?;
    // The texture is in buffer pixels; the client's scale maps it back to the
    // surface's logical size.
    let buffer_scale = window_render_scale(meta_window).round().max(1.0) as i32;
    let element = TextureRenderElement::from_static_texture(
        Id::new(),
        renderer.context_id(),
        location.to_f64(),
        texture,
        buffer_scale,
        Transform::Normal,
        None,
        None,
        None,
        None,
        Kind::Unspecified,
    );
    let pixels = render_pixels(renderer, size, &[PreviewElements::Texture(element)])?;
    Ok((size, pixels))
}

/// Renders [elements] over a transparent background into CPU pixels.
fn render_pixels(
    renderer: &mut GlesRenderer,
    size: Size<i32, Physical>,
    elements: &[PreviewElements],
) -> Result<Vec<u8>, String> {
    let buffer_size = Size::<i32, Buffer>::from((size.w, size.h));
    let mut buffer: GlesRenderbuffer = renderer
        .create_buffer(Fourcc::Abgr8888, buffer_size)
        .map_err(|error| format!("unable to allocate the frame: {error}"))?;
    let mut target = renderer
        .bind(&mut buffer)
        .map_err(|error| format!("unable to bind the frame: {error}"))?;
    OutputDamageTracker::new(size, 1.0, Transform::Normal)
        .render_output(renderer, &mut target, 0, elements, [0.0, 0.0, 0.0, 0.0])
        .map_err(|error| format!("unable to render the frame: {error}"))?;
    let mapping = renderer
        .copy_framebuffer(&target, Rectangle::from_size(buffer_size), Fourcc::Abgr8888)
        .map_err(|error| format!("unable to read the frame: {error}"))?;
    renderer
        .map_texture(&mapping)
        .map(|pixels| pixels.to_vec())
        .map_err(|error| format!("unable to map the frame: {error}"))
}

/// Renders [elements] over a transparent background into a texture the
/// compositor owns.
fn render_texture(
    renderer: &mut GlesRenderer,
    size: Size<i32, Physical>,
    scale: f64,
    elements: &[PreviewElements],
) -> Result<GlesTexture, String> {
    let mut texture: GlesTexture = renderer
        .create_buffer(
            Fourcc::Abgr8888,
            Size::<i32, Buffer>::from((size.w, size.h)),
        )
        .map_err(|error| format!("unable to allocate the frame: {error}"))?;
    {
        let mut target = renderer
            .bind(&mut texture)
            .map_err(|error| format!("unable to bind the frame: {error}"))?;
        OutputDamageTracker::new(size, scale, Transform::Normal)
            .render_output(renderer, &mut target, 0, elements, [0.0, 0.0, 0.0, 0.0])
            .map_err(|error| format!("unable to render the frame: {error}"))?;
    }
    debug_assert_eq!(texture.size().w, size.w);
    Ok(texture)
}

/// The shell's frost strength for a region of [size] logical pixels; keep in
/// step with `frostSigmaFor` (`src/shell/lib/shared/widget/frosted_surface.dart`).
fn frost_sigma(size: Size<i32, Physical>) -> f64 {
    (size.w.min(size.h).max(0) as f64 * 0.02).clamp(8.0, 28.0)
}

/// Blur of the stored preview, in its own pixels.
///
/// The preview keeps one pixel per frost sigma: averaging that far down is
/// what removes the window's detail for good (no deblurring brings back what
/// was averaged together), and a further 1 px Gaussian makes the whole match
/// the shell's frost once it is scaled back up to the window's size.
const STORED_SIGMA: f64 = 1.0;

/// Turns one rendered frame (premultiplied RGBA, one pixel per logical pixel)
/// into the stored preview: averaged down to one pixel per frost sigma,
/// blurred, and un-premultiplied for PNG. `None` when the frame has nothing
/// to show.
pub(crate) fn bake_preview(
    size: Size<i32, Physical>,
    pixels: &[u8],
) -> Option<(Size<i32, Physical>, Vec<u8>)> {
    if size.w <= 0 || size.h <= 0 || pixels.len() < (size.w * size.h * 4) as usize {
        return None;
    }
    let pitch = frost_sigma(size);
    let target = Size::<i32, Physical>::from((
        ((size.w as f64 / pitch).ceil() as i32).max(1),
        ((size.h as f64 / pitch).ceil() as i32).max(1),
    ));
    let averaged = area_average(size, pixels, target);
    if is_blank(&averaged) {
        return None;
    }
    let mut blurred = gaussian_blur(target, &averaged, STORED_SIGMA);
    unpremultiply(&mut blurred);
    Some((target, blurred))
}

/// Box-filters [pixels] down to [target]: each output pixel is the mean of
/// the source pixels it covers.
fn area_average(size: Size<i32, Physical>, pixels: &[u8], target: Size<i32, Physical>) -> Vec<u8> {
    let (width, height) = (size.w as usize, size.h as usize);
    let (out_width, out_height) = (target.w as usize, target.h as usize);
    let span = |index: usize, out: usize, source: usize| {
        let start = index * source / out;
        let end = ((index + 1) * source / out).max(start + 1).min(source);
        start..end
    };
    let mut out = vec![0u8; out_width * out_height * 4];
    for out_y in 0..out_height {
        let rows = span(out_y, out_height, height);
        for out_x in 0..out_width {
            let columns = span(out_x, out_width, width);
            let mut sum = [0u64; 4];
            for y in rows.clone() {
                let row = &pixels[(y * width + columns.start) * 4..(y * width + columns.end) * 4];
                for pixel in row.as_chunks::<4>().0 {
                    for channel in 0..4 {
                        sum[channel] += pixel[channel] as u64;
                    }
                }
            }
            let count = (rows.len() * columns.len()) as u64;
            let target = (out_y * out_width + out_x) * 4;
            for channel in 0..4 {
                out[target + channel] = ((sum[channel] + count / 2) / count) as u8;
            }
        }
    }
    out
}

/// Whether a frame shows nothing: fully transparent, or one plain colour.
fn is_blank(pixels: &[u8]) -> bool {
    let Some(first) = pixels.as_chunks::<4>().0.iter().next() else {
        return true;
    };
    pixels.as_chunks::<4>().0.iter().all(|pixel| pixel[3] == 0)
        || pixels.as_chunks::<4>().0.iter().all(|pixel| {
            pixel
                .iter()
                .zip(first)
                .all(|(value, reference)| value.abs_diff(*reference) <= 2)
        })
}

/// Separable Gaussian blur of an RGBA image, edges clamped.
fn gaussian_blur(size: Size<i32, Physical>, pixels: &[u8], sigma: f64) -> Vec<u8> {
    let (width, height) = (size.w as usize, size.h as usize);
    let radius = (sigma * 3.0).ceil() as isize;
    let mut kernel: Vec<f64> = (-radius..=radius)
        .map(|offset| (-(offset * offset) as f64 / (2.0 * sigma * sigma)).exp())
        .collect();
    let total: f64 = kernel.iter().sum();
    kernel.iter_mut().for_each(|weight| *weight /= total);

    let pass = |source: &[f64], horizontal: bool| -> Vec<f64> {
        let mut out = vec![0.0; source.len()];
        for y in 0..height {
            for x in 0..width {
                let mut sum = [0.0; 4];
                for (tap, weight) in kernel.iter().enumerate() {
                    let offset = tap as isize - radius;
                    let (sx, sy) = if horizontal {
                        (
                            (x as isize + offset).clamp(0, width as isize - 1) as usize,
                            y,
                        )
                    } else {
                        (
                            x,
                            (y as isize + offset).clamp(0, height as isize - 1) as usize,
                        )
                    };
                    let index = (sy * width + sx) * 4;
                    for channel in 0..4 {
                        sum[channel] += source[index + channel] * weight;
                    }
                }
                out[(y * width + x) * 4..(y * width + x) * 4 + 4].copy_from_slice(&sum);
            }
        }
        out
    };
    let source: Vec<f64> = pixels.iter().map(|value| *value as f64).collect();
    let blurred = pass(&pass(&source, true), false);
    blurred
        .iter()
        .map(|value| value.round().clamp(0.0, 255.0) as u8)
        .collect()
}

/// Converts premultiplied RGBA (what the renderer reads back) to the straight
/// alpha PNG stores.
fn unpremultiply(pixels: &mut [u8]) {
    for pixel in pixels.as_chunks_mut::<4>().0 {
        let alpha = pixel[3] as u32;
        if alpha == 0 || alpha == 255 {
            continue;
        }
        for channel in &mut pixel[..3] {
            *channel = ((*channel as u32 * 255 + alpha / 2) / alpha).min(255) as u8;
        }
    }
}

/// Writes [pixels] as a PNG readable by the user only, atomically.
fn write_private_png(path: &Path, size: Size<i32, Physical>, pixels: &[u8]) -> Result<(), String> {
    let parent = path
        .parent()
        .ok_or_else(|| format!("{} has no parent directory", path.display()))?;
    DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(parent)
        .map_err(|error| format!("unable to create {}: {error}", parent.display()))?;
    let png = encode_png(size, pixels).map_err(|error| format!("unable to encode: {error}"))?;
    let part = path.with_extension("png.part");
    let written = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o600)
        .open(&part)
        .and_then(|mut file| file.write_all(&png))
        .and_then(|()| fs::rename(&part, path));
    if let Err(error) = written {
        let _ = fs::remove_file(&part);
        return Err(format!("unable to write {}: {error}", path.display()));
    }
    Ok(())
}

/// Removes the previews of tiles that no longer exist: a tile whose state file
/// (`persistent_window_<uuid>.json` in [persistence_directory]) is gone.
///
/// A preview can outlive its tile when the window wrote it after the tile was
/// removed; nothing else would ever delete it.
pub fn sweep_orphan_previews(cache_directory: &Path, persistence_directory: &Path) {
    let Ok(entries) = fs::read_dir(cache_directory.join(PREVIEW_DIRECTORY)) else {
        return;
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        let Some(name) = name.to_str() else {
            continue;
        };
        let uuid = name.split('.').next().unwrap_or_default();
        let orphan = name.ends_with(".part")
            || !persistence_directory
                .join(format!("persistent_window_{uuid}.json"))
                .exists();
        if orphan {
            if let Err(error) = fs::remove_file(entry.path()) {
                warn!("Unable to remove the stale preview {name}: {error}");
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn opaque(size: (i32, i32), color: impl Fn(usize, usize) -> [u8; 3]) -> Vec<u8> {
        let mut pixels = Vec::with_capacity((size.0 * size.1 * 4) as usize);
        for y in 0..size.1 as usize {
            for x in 0..size.0 as usize {
                pixels.extend_from_slice(&color(x, y));
                pixels.push(255);
            }
        }
        pixels
    }

    #[test]
    fn the_preview_keeps_one_pixel_per_frost_sigma() {
        // A 1232x752 tile frosts at sigma 15.04 in the shell.
        let pixels = opaque((1232, 752), |x, _| if x < 616 { [0; 3] } else { [255; 3] });
        let (size, baked) = bake_preview((1232, 752).into(), &pixels).unwrap();
        assert_eq!((size.w, size.h), (82, 50));
        assert_eq!(baked.len(), 82 * 50 * 4);
        // Small windows still frost at sigma 8, huge ones at 28 at most.
        let small = opaque((400, 300), |x, _| [x as u8, 0, 0]);
        assert_eq!(
            bake_preview((400, 300).into(), &small).unwrap().0,
            (50, 38).into()
        );
        assert_eq!(frost_sigma((10000, 8000).into()), 28.0);
    }

    #[test]
    fn text_does_not_survive_the_preview() {
        // One-pixel strokes every other pixel (the finest detail a window
        // has) on the left half, plain black on the right.
        let pixels = opaque((800, 600), |x, y| {
            if x < 400 && (x + y) % 2 == 0 {
                [255; 3]
            } else {
                [0; 3]
            }
        });
        let (size, baked) = bake_preview((800, 600).into(), &pixels).unwrap();
        // Sigma 12: 67 columns, the strokes cover the first 33.
        assert_eq!((size.w, size.h), (67, 50));
        for y in 0..size.h as usize {
            for x in 0..25 {
                let value = baked[(y * size.w as usize + x) * 4];
                assert!(value.abs_diff(128) <= 2, "({x}, {y}) is {value}");
            }
        }
    }

    #[test]
    fn a_blank_frame_is_not_stored() {
        let transparent = vec![0u8; 200 * 100 * 4];
        assert!(bake_preview((200, 100).into(), &transparent).is_none());
        let white = opaque((200, 100), |_, _| [255; 3]);
        assert!(bake_preview((200, 100).into(), &white).is_none());
    }

    #[test]
    fn the_blur_spreads_a_point_over_its_neighbours() {
        let mut pixels = vec![0u8; 9 * 9 * 4];
        let center = (4 * 9 + 4) * 4;
        pixels[center..center + 4].copy_from_slice(&[255, 255, 255, 255]);
        let blurred = gaussian_blur((9, 9).into(), &pixels, 1.0);
        assert!(blurred[center] < 255 && blurred[center] > 0);
        assert!(blurred[center + 4] > 0);
        assert_eq!(blurred[0], 0);
    }

    #[test]
    fn premultiplied_pixels_are_restored_for_png() {
        let mut pixels = vec![64, 32, 0, 128];
        unpremultiply(&mut pixels);
        assert_eq!(pixels, vec![128, 64, 0, 128]);
    }

    #[test]
    fn the_preview_is_private_to_the_user() {
        use std::os::unix::fs::PermissionsExt;
        let directory = std::env::temp_dir().join(format!(
            "veshell-preview-test-{}-{}",
            std::process::id(),
            line!()
        ));
        let path = preview_path(&directory, "tile");
        write_private_png(&path, (1, 1).into(), &[1, 2, 3, 255]).unwrap();
        let mode = |path: &Path| fs::metadata(path).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode(&path), 0o600);
        assert_eq!(mode(path.parent().unwrap()), 0o700);
        fs::remove_dir_all(&directory).unwrap();
    }

    #[test]
    fn previews_of_removed_tiles_are_swept() {
        let root = std::env::temp_dir().join(format!(
            "veshell-preview-sweep-{}-{}",
            std::process::id(),
            line!()
        ));
        let cache = root.join("cache");
        let persistence = root.join("persistence");
        fs::create_dir_all(cache.join(PREVIEW_DIRECTORY)).unwrap();
        fs::create_dir_all(&persistence).unwrap();
        fs::write(persistence.join("persistent_window_kept.json"), "{}").unwrap();
        for name in [
            "kept.png",
            "kept.layout",
            "gone.png",
            "gone.layout",
            "kept.png.part",
        ] {
            fs::write(cache.join(PREVIEW_DIRECTORY).join(name), "").unwrap();
        }

        sweep_orphan_previews(&cache, &persistence);

        let mut left: Vec<_> = fs::read_dir(cache.join(PREVIEW_DIRECTORY))
            .unwrap()
            .map(|entry| entry.unwrap().file_name().into_string().unwrap())
            .collect();
        left.sort();
        assert_eq!(left, ["kept.layout", "kept.png"]);
        fs::remove_dir_all(&root).unwrap();
    }
}
