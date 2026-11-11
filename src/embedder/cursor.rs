use std::env;
use std::{
    collections::HashMap,
    io::Read,
    sync::{Mutex, OnceLock},
};

use smithay::backend::renderer::RendererSuper;
use smithay::output::Scale;
use smithay::utils;
use smithay::{
    backend::{
        allocator::Fourcc,
        renderer::{
            element::{
                memory::{MemoryRenderBuffer, MemoryRenderBufferRenderElement},
                surface::{render_elements_from_surface_tree, WaylandSurfaceRenderElement},
                Kind,
            },
            ImportAll, ImportMem, Renderer,
        },
    },
    input::pointer::{CursorIcon, CursorImageAttributes, CursorImageStatus},
    reexports::wayland_server::protocol::wl_surface::WlSurface,
    render_elements,
    utils::{IsAlive, Logical, Monotonic, Physical, Point, Rectangle, Size, Time, Transform},
    wayland::compositor::with_states,
};
use tracing::warn;
use xcursor::{
    parser::{parse_xcursor, Image},
    CursorTheme,
};

static FALLBACK_CURSOR_DATA: &[u8] = include_bytes!("resources/cursor.rgba");

pub struct Cursor {
    icons: Vec<Image>,
}

impl Cursor {
    pub fn load(theme: &CursorTheme, shape: CursorIcon) -> Cursor {
        let icons = load_icon(theme, shape)
            .map_err(|err| warn!(?err, "Unable to load xcursor, using fallback cursor"))
            .or_else(|_| load_icon(theme, CursorIcon::Default))
            .unwrap_or_else(|_| {
                vec![Image {
                    size: 32,
                    width: 64,
                    height: 64,
                    xhot: 1,
                    yhot: 1,
                    delay: 1,
                    pixels_rgba: Vec::from(FALLBACK_CURSOR_DATA),
                    pixels_argb: vec![], //unused
                }]
            });

        Cursor { icons }
    }

    /// The frame whose nominal size is closest to `size` physical pixels.
    ///
    /// The frame is drawn at its own pixel size (see
    /// [`native_cursor_placement`]); `size` only picks the theme image, so a
    /// theme without an image for the requested size falls back to its nearest
    /// one instead of being resampled and blurred.
    pub fn get_image(&self, size: u32, millis: u32) -> Image {
        frame(millis, size, &self.icons)
    }
}

/// Where a theme bitmap is drawn on an output.
#[derive(Debug, PartialEq)]
struct NativeCursorPlacement {
    /// Logical size handed to the render element. It is the bitmap's pixel
    /// size divided by the output scale, rounded to whole logical pixels, so
    /// the element maps the bitmap back to its native physical size.
    logical_size: Size<i32, Logical>,
    /// Physical hotspot of the drawn bitmap. The bitmap is not resampled, so
    /// this follows from its pixel size and the (rounded) logical size.
    hotspot: Point<i32, Physical>,
}

/// Places a cursor bitmap at its native resolution on an output of `scale`.
///
/// Resampling a cursor blurs it. Instead, the bitmap is drawn at (or within a
/// pixel of) its own pixel size, and its size on screen is the theme image's,
/// chosen to be the closest to the configured logical size times the output
/// scale. Themes ship the physical sizes used by common scales (for example
/// Adwaita has 30 px for 1.25 and 36 px for 1.5 for a 24 logical cursor).
fn native_cursor_placement(frame: &Image, scale: f64) -> NativeCursorPlacement {
    let logical = |px: u32| (f64::from(px) / scale).round().max(1.0) as i32;
    let logical_w = logical(frame.width);
    let logical_h = logical(frame.height);
    let physical = |logical: i32| (f64::from(logical) * scale).round();
    let hotspot = |px: u32, hotspot: u32, physical: f64| {
        (f64::from(hotspot) * physical / f64::from(px)).round() as i32
    };
    NativeCursorPlacement {
        logical_size: Size::from((logical_w, logical_h)),
        hotspot: Point::from((
            hotspot(frame.width, frame.xhot, physical(logical_w)),
            hotspot(frame.height, frame.yhot, physical(logical_h)),
        )),
    }
}

render_elements! {
    pub CursorRenderElement<R> where R: ImportAll + ImportMem;
    Static=MemoryRenderBufferRenderElement<R>,
    Surface=WaylandSurfaceRenderElement<R>,
}

fn nearest_images(size: u32, images: &[Image]) -> impl Iterator<Item = &Image> {
    // Follow the nominal size of the cursor to choose the nearest
    let nearest_image = images
        .iter()
        .min_by_key(|image| (size as i32 - image.size as i32).abs())
        .unwrap();

    images.iter().filter(move |image| {
        image.width == nearest_image.width && image.height == nearest_image.height
    })
}

fn frame(mut millis: u32, size: u32, images: &[Image]) -> Image {
    let total = nearest_images(size, images).fold(0, |acc, image| acc + image.delay);
    millis %= total;

    for img in nearest_images(size, images) {
        if millis < img.delay {
            return img.clone();
        }
        millis -= img.delay;
    }

    unreachable!()
}

#[derive(thiserror::Error, Debug)]
enum Error {
    #[error("Theme has no default cursor")]
    NoDefaultCursor,
    #[error("Error opening xcursor file: {0}")]
    File(#[from] std::io::Error),
    #[error("Failed to parse XCursor file")]
    Parse,
}

fn load_icon(theme: &CursorTheme, shape: CursorIcon) -> Result<Vec<Image>, Error> {
    let icon_path = theme
        .load_icon(&shape.to_string())
        .ok_or(Error::NoDefaultCursor)?;
    let mut cursor_file = std::fs::File::open(&icon_path)?;
    let mut cursor_data = Vec::new();
    cursor_file.read_to_end(&mut cursor_data)?;
    parse_xcursor(&cursor_data).ok_or(Error::Parse)
}

pub type CursorState = Mutex<CursorStateInner>;
pub struct CursorStateInner {
    /// Last shape requested by Flutter through `flutter/mousecursor`.
    flutter_cursor: Option<CursorIcon>,
    /// Shape forced by a compositor-owned grab (floating move or resize).
    ///
    /// Kept apart from [`Self::flutter_cursor`]: Flutter keeps receiving motion
    /// during the grab and may report its own cursor, which must not replace
    /// the grab feedback, and ending the grab must restore Flutter's shape
    /// rather than forget it.
    grab_cursor: Option<CursorIcon>,
    /// Whether a shell transition (a sliding tile row or workspace) is in
    /// progress. Flutter reports the arrow while the page under the pointer
    /// leaves the hit test, although it is still painted, so its updates are
    /// recorded but not displayed meanwhile.
    transitioning: bool,
    /// The shape Flutter reported during [`Self::transitioning`], applied when
    /// the transition ends.
    pending_flutter_cursor: Option<CursorIcon>,

    cursor_theme: CursorTheme,
    cursor_theme_name: String,
    cursor_size: u32,

    cursors: HashMap<CursorIcon, Cursor>,
    current_image: Option<Image>,
    image_cache: Vec<(Image, MemoryRenderBuffer)>,
}

impl CursorStateInner {
    /// Records the shape Flutter asked for. Returns whether the displayed
    /// cursor changed, so the caller knows to schedule a render.
    pub fn set_flutter_shape(&mut self, shape: CursorIcon) -> bool {
        if self.transitioning {
            self.pending_flutter_cursor = Some(shape);
            return false;
        }
        let before = self.shape();
        self.flutter_cursor = Some(shape);
        before != self.shape()
    }

    /// Starts or ends a shell transition.
    ///
    /// While one runs, Flutter's cursor reports are kept pending instead of
    /// applied: a page leaving the hit test reports the arrow even though it
    /// is still painted under a stationary pointer, and showing it would blink
    /// the cursor on every navigation. Ending the transition applies the last
    /// shape Flutter reported. Returns whether the displayed cursor changed,
    /// so the caller knows to schedule a render.
    pub fn set_transitioning(&mut self, transitioning: bool) -> bool {
        if self.transitioning == transitioning {
            return false;
        }
        self.transitioning = transitioning;
        if transitioning {
            return false;
        }
        let Some(shape) = self.pending_flutter_cursor.take() else {
            return false;
        };
        let before = self.shape();
        self.flutter_cursor = Some(shape);
        before != self.shape()
    }

    /// Forces `shape` for the duration of a compositor-owned grab.
    pub fn set_grab_shape(&mut self, shape: CursorIcon) -> bool {
        let before = self.shape();
        self.grab_cursor = Some(shape);
        before != self.shape()
    }

    /// Ends the grab override; Flutter's last shape shows again.
    pub fn clear_grab_shape(&mut self) -> bool {
        let before = self.shape();
        self.grab_cursor = None;
        before != self.shape()
    }

    /// The shell-chosen shape currently displayed, if any.
    pub fn shape(&self) -> Option<CursorIcon> {
        self.grab_cursor.or(self.flutter_cursor)
    }

    /// Whether the shell deliberately claims the cursor over client surfaces.
    ///
    /// Over a client surface Flutter has no cursor of its own and reports the
    /// default arrow, which defers to the client's cursor image. Any other
    /// shape comes from a shell region placed over the surface on purpose (a
    /// Super-hover tile grab, a resize edge) or from a compositor grab, and
    /// must show instead of whatever the client set.
    pub fn overrides_clients(&self) -> bool {
        self.grab_cursor.is_some()
            || self
                .flutter_cursor
                .is_some_and(|c| c != CursorIcon::Default)
    }

    pub fn get_named_cursor(&mut self, shape: CursorIcon) -> &Cursor {
        self.cursors
            .entry(shape)
            .or_insert_with(|| Cursor::load(&self.cursor_theme, shape))
    }
}

/// Size used when neither the setting nor the environment chooses one.
pub const DEFAULT_CURSOR_SIZE: u32 = 24;

/// The cursor theme and size the session asked for before Veshell applied its
/// own setting (`XCURSOR_THEME`/`XCURSOR_SIZE`, else `default`/24).
///
/// Read once: applying the setting rewrites those variables, so later reads
/// would only see Veshell's own value and clearing the setting could never go
/// back to the session's choice.
fn session_cursor_defaults() -> &'static (String, u32) {
    static DEFAULTS: OnceLock<(String, u32)> = OnceLock::new();
    DEFAULTS.get_or_init(|| {
        let name = env::var("XCURSOR_THEME")
            .ok()
            .filter(|name| !name.is_empty())
            .unwrap_or_else(|| "default".into());
        let size = env::var("XCURSOR_SIZE")
            .ok()
            .and_then(|s| s.parse().ok())
            .filter(|size| *size > 0)
            .unwrap_or(DEFAULT_CURSOR_SIZE);
        (name, size)
    })
}

/// The effective cursor theme name and nominal size for the `theme.cursorTheme`
/// and `theme.cursorSize` settings. An empty theme or a zero size keeps the
/// session's value.
pub fn resolve_cursor_config(theme: &str, size: u32) -> (String, u32) {
    let (session_theme, session_size) = session_cursor_defaults();
    let theme = theme.trim();
    (
        if theme.is_empty() {
            session_theme.clone()
        } else {
            theme.to_owned()
        },
        if size == 0 { *session_size } else { size },
    )
}

/// Exports the effective cursor to the compositor's environment, which
/// children spawned directly inherit and the session import forwards.
fn export_cursor_environment(name: &str, size: u32) {
    env::set_var("XCURSOR_THEME", name);
    env::set_var("XCURSOR_SIZE", size.to_string());
}

impl CursorStateInner {
    /// Builds the cursor state for the configured theme and size.
    pub fn new(theme: &str, size: u32) -> Self {
        let (name, size) = resolve_cursor_config(theme, size);
        export_cursor_environment(&name, size);
        CursorStateInner {
            flutter_cursor: None,
            grab_cursor: None,
            transitioning: false,
            pending_flutter_cursor: None,

            cursor_theme: CursorTheme::load(&name),
            cursor_theme_name: name,
            cursor_size: size,

            cursors: HashMap::new(),
            current_image: None,

            image_cache: Vec::new(),
        }
    }

    /// Switches to another theme or size. Returns whether anything changed;
    /// the caller then repaints and refreshes Xwayland.
    pub fn set_theme(&mut self, theme: &str, size: u32) -> bool {
        let (name, size) = resolve_cursor_config(theme, size);
        if name == self.cursor_theme_name && size == self.cursor_size {
            return false;
        }
        export_cursor_environment(&name, size);
        self.cursor_theme = CursorTheme::load(&name);
        self.cursor_theme_name = name;
        self.cursor_size = size;
        // Loaded shapes and their uploaded frames belong to the old theme.
        self.cursors.clear();
        self.image_cache.clear();
        self.current_image = None;
        true
    }

    /// The effective theme name, as exported in `XCURSOR_THEME`.
    pub fn theme_name(&self) -> &str {
        &self.cursor_theme_name
    }

    /// The effective nominal size, as exported in `XCURSOR_SIZE`.
    pub fn size(&self) -> u32 {
        self.cursor_size
    }

    /// The default arrow of the current theme.
    pub fn default_cursor(&mut self) -> &Cursor {
        self.get_named_cursor(CursorIcon::Default)
    }
}

impl Default for CursorStateInner {
    /// The session's cursor, before any setting applies.
    fn default() -> CursorStateInner {
        CursorStateInner::new("", 0)
    }
}

/// What the pointer shows.
#[derive(Debug, PartialEq)]
enum CursorChoice {
    /// A client-drawn cursor surface.
    Surface(WlSurface),
    /// A shape drawn from the configured theme and size.
    Named(CursorIcon),
    Hidden,
}

/// Picks the cursor from the client's request and the shell's shape.
///
/// When the client owns the cursor (it is under the pointer and the shell does
/// not claim it, or a game owns the output) its request is honoured as is: a
/// surface it draws, a shape it named through `wp_cursor_shape_v1` (drawn from
/// the configured theme, so theme and size settings reach it live), or no
/// cursor at all. The shell's arrow must not cover a named shape there: Flutter
/// reports `basic` over every client surface. Elsewhere the shell's shape wins,
/// falling back to a named client shape and then to nothing.
fn choose_cursor(
    client: CursorImageStatus,
    shell: Option<CursorIcon>,
    client_owns_cursor: bool,
) -> CursorChoice {
    if client_owns_cursor {
        return match client {
            CursorImageStatus::Surface(surface) => CursorChoice::Surface(surface),
            CursorImageStatus::Named(icon) => CursorChoice::Named(icon),
            CursorImageStatus::Hidden => CursorChoice::Hidden,
        };
    }
    match (shell, client) {
        (Some(icon), _) | (None, CursorImageStatus::Named(icon)) => CursorChoice::Named(icon),
        _ => CursorChoice::Hidden,
    }
}

pub fn draw_cursor<R>(
    renderer: &mut R,
    cursor_image_status: &Mutex<CursorImageStatus>,
    cursor_state: &Mutex<CursorStateInner>,
    scale: Scale,
    time: Time<Monotonic>,
    location: Point<f64, Logical>,
    is_surface_under_pointer: bool,
    gaming_mode: bool,
) -> Vec<(CursorRenderElement<R>, Point<i32, Physical>)>
where
    R: Renderer + ImportMem + ImportAll,
    <R as RendererSuper>::TextureId: Send + Clone + 'static,
{
    let cursor_status = {
        let cursor_image_status = cursor_image_status.lock().unwrap();

        match *cursor_image_status {
            CursorImageStatus::Surface(ref surface) if !surface.alive() => {
                CursorImageStatus::default_named()
            }
            ref status => status.clone(),
        }
    };

    let mut state_ref = cursor_state.lock().unwrap();
    let state = &mut *state_ref;

    // The game is under the pointer by definition while it owns the output,
    // even though the shell stops reporting a surface under the cursor.
    let client_owns_cursor =
        gaming_mode || (is_surface_under_pointer && !state.overrides_clients());
    let named_cursor = match choose_cursor(cursor_status, state.shape(), client_owns_cursor) {
        CursorChoice::Surface(wl_surface) => {
            return draw_surface_cursor(
                renderer,
                &wl_surface,
                location.to_i32_round(),
                scale.fractional_scale().into(),
            );
        }
        CursorChoice::Named(icon) => Some(icon),
        CursorChoice::Hidden => None,
    };
    if let Some(current_cursor) = named_cursor {
        let float_scale: utils::Scale<f64> = scale.fractional_scale().into();
        let output_scale = scale.fractional_scale();
        // The bitmap nearest the size this output needs is drawn at its own
        // pixel size. Resampling to force an exact logical size would blur the
        // pointer; themes ship the physical sizes for common scales instead.
        let target_px = (f64::from(state.size()) * output_scale).round().max(1.0) as u32;
        let frame = state
            .get_named_cursor(current_cursor)
            .get_image(target_px, time.as_millis());
        let placement = native_cursor_placement(&frame, output_scale);

        let pointer_images = &mut state.image_cache;
        let maybe_image =
            pointer_images
                .iter()
                .find_map(|(image, texture)| if image == &frame { Some(texture) } else { None });
        let pointer_image = match maybe_image {
            Some(image) => image,
            None => {
                let buffer = MemoryRenderBuffer::from_slice(
                    &frame.pixels_rgba,
                    Fourcc::Argb8888,
                    (frame.width as i32, frame.height as i32),
                    1,
                    Transform::Normal,
                    None,
                );
                pointer_images.push((frame.clone(), buffer));
                pointer_images.last().map(|(_, i)| i).unwrap()
            }
        };

        state.current_image = Some(frame.clone());
        vec![(
            CursorRenderElement::Static(
                MemoryRenderBufferRenderElement::from_buffer(
                    renderer,
                    location.to_physical_precise_round(float_scale),
                    pointer_image,
                    None,
                    // The whole bitmap (it is uploaded with buffer scale 1)…
                    Some(Rectangle::from_size(Size::from((
                        frame.width as f64,
                        frame.height as f64,
                    )))),
                    // …stretched to the rounded logical size, which lands it
                    // back on its native pixel size.
                    Some(placement.logical_size),
                    Kind::Cursor,
                )
                .expect("Failed to import cursor bitmap"),
            ),
            placement.hotspot,
        )]
    } else {
        Vec::new()
    }
}

pub fn draw_surface_cursor<R>(
    renderer: &mut R,
    surface: &WlSurface,
    location: impl Into<Point<i32, Logical>>,
    scale: utils::Scale<f64>,
) -> Vec<(CursorRenderElement<R>, Point<i32, Physical>)>
where
    R: Renderer + ImportAll,
    <R as RendererSuper>::TextureId: Clone + 'static,
{
    let position = location.into();
    // The hotspot is in surface-local (logical) coordinates; the element is
    // placed in physical pixels, so it has to follow the output scale.
    let h: Point<i32, Physical> = with_states(surface, |states| {
        states
            .data_map
            .get::<Mutex<CursorImageAttributes>>()
            .unwrap()
            .lock()
            .unwrap()
            .hotspot
            .to_f64()
            .to_physical(scale)
            .to_i32_round()
    });

    render_elements_from_surface_tree(
        renderer,
        surface,
        position.to_physical_precise_round(scale),
        scale,
        1.0,
        Kind::Cursor,
    )
    .into_iter()
    .map(|elem| (elem, h))
    .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn configured_cursor_wins_and_empty_keeps_the_session() {
        assert_eq!(
            resolve_cursor_config(" Breeze_Snow ", 48),
            ("Breeze_Snow".to_owned(), 48)
        );
        assert_eq!(
            resolve_cursor_config("", 0),
            session_cursor_defaults().clone()
        );
    }

    #[test]
    fn set_theme_reports_only_real_changes() {
        let mut state = CursorStateInner::new("Breeze_Snow", 32);
        assert!(!state.set_theme("Breeze_Snow", 32));
        assert!(state.set_theme("Breeze_Snow", 48));
        assert_eq!(state.size(), 48);
        assert!(state.set_theme("Adwaita", 48));
        assert_eq!(state.theme_name(), "Adwaita");
    }

    #[test]
    fn a_client_owning_the_cursor_keeps_its_named_shape() {
        // Flutter reports `basic` over every client surface; it must not
        // cover a shape the client named through `wp_cursor_shape_v1`.
        assert_eq!(
            choose_cursor(
                CursorImageStatus::Named(CursorIcon::Text),
                Some(CursorIcon::Default),
                true,
            ),
            CursorChoice::Named(CursorIcon::Text)
        );
        assert_eq!(
            choose_cursor(CursorImageStatus::Hidden, Some(CursorIcon::Default), true),
            CursorChoice::Hidden
        );
    }

    #[test]
    fn the_shell_shape_wins_where_the_client_does_not_own_the_cursor() {
        assert_eq!(
            choose_cursor(
                CursorImageStatus::Named(CursorIcon::Text),
                Some(CursorIcon::Grab),
                false,
            ),
            CursorChoice::Named(CursorIcon::Grab)
        );
        assert_eq!(
            choose_cursor(CursorImageStatus::Named(CursorIcon::Text), None, false),
            CursorChoice::Named(CursorIcon::Text)
        );
        assert_eq!(
            choose_cursor(CursorImageStatus::Hidden, None, false),
            CursorChoice::Hidden
        );
    }

    #[test]
    fn default_flutter_cursor_defers_to_clients() {
        let mut state = CursorStateInner::default();
        assert!(!state.overrides_clients());
        state.set_flutter_shape(CursorIcon::Default);
        assert!(!state.overrides_clients());
    }

    #[test]
    fn deliberate_shell_cursors_override_clients() {
        let mut state = CursorStateInner::default();
        state.set_flutter_shape(CursorIcon::Grab);
        assert!(state.overrides_clients());

        state.set_flutter_shape(CursorIcon::Default);
        state.set_grab_shape(CursorIcon::Grabbing);
        assert!(state.overrides_clients());
        assert_eq!(state.shape(), Some(CursorIcon::Grabbing));

        state.clear_grab_shape();
        assert!(!state.overrides_clients());
        assert_eq!(state.shape(), Some(CursorIcon::Default));
    }

    #[test]
    fn a_transition_holds_the_cursor_and_applies_the_last_shape_reported() {
        let mut state = CursorStateInner::default();
        assert!(state.set_flutter_shape(CursorIcon::Grab));

        assert!(!state.set_transitioning(true));
        // The page under the pointer left the hit test and reports the arrow;
        // the hand stays.
        assert!(!state.set_flutter_shape(CursorIcon::Default));
        assert_eq!(state.shape(), Some(CursorIcon::Grab));
        // The settled layout reports the window under the pointer; the hand
        // still stays until the transition ends.
        assert!(!state.set_flutter_shape(CursorIcon::Pointer));
        assert_eq!(state.shape(), Some(CursorIcon::Grab));

        assert!(state.set_transitioning(false));
        assert_eq!(state.shape(), Some(CursorIcon::Pointer));
        assert!(state.set_flutter_shape(CursorIcon::Default));
        assert_eq!(state.shape(), Some(CursorIcon::Default));
    }

    #[test]
    fn a_transition_end_without_a_new_shape_keeps_the_current_one() {
        let mut state = CursorStateInner::default();
        state.set_flutter_shape(CursorIcon::Grab);
        state.set_transitioning(true);

        assert!(!state.set_transitioning(false));
        assert_eq!(state.shape(), Some(CursorIcon::Grab));
    }

    fn test_icon(size: u32) -> Image {
        Image {
            size,
            width: size,
            height: size,
            xhot: 4,
            yhot: 4,
            delay: 1,
            pixels_rgba: vec![0; (size * size * 4) as usize],
            pixels_argb: vec![],
        }
    }

    #[test]
    fn the_theme_frame_nearest_the_physical_target_is_chosen() {
        let cursor = Cursor {
            icons: vec![test_icon(24), test_icon(36), test_icon(48)],
        };
        assert_eq!(cursor.get_image(36, 0).size, 36);
        assert_eq!(cursor.get_image(48, 0).size, 48);
        assert_eq!(cursor.get_image(40, 0).size, 36);
        assert_eq!(cursor.get_image(20, 0).size, 24);
    }

    #[test]
    fn a_bitmap_is_drawn_at_its_native_pixel_size() {
        // Adwaita's 36 px arrow is the 1.5× image of its 24 px cursor; drawn
        // on a 150% output it must stay 36 physical pixels, at 24 logical.
        let placement = native_cursor_placement(&test_icon(36), 1.5);
        assert_eq!(placement.logical_size, Size::from((24, 24)));
        assert_eq!(placement.hotspot, Point::from((4, 4)));
        assert_eq!((f64::from(placement.logical_size.w) * 1.5).round(), 36.0);
    }

    #[test]
    fn integer_scales_keep_the_bitmap_pixel_for_pixel() {
        let placement = native_cursor_placement(&test_icon(48), 2.0);
        assert_eq!(placement.logical_size, Size::from((24, 24)));
        assert_eq!(placement.hotspot, Point::from((4, 4)));
    }

    #[test]
    fn a_bitmap_the_theme_lacks_is_not_resampled_to_the_setting() {
        // Bibata ships 24/32/48. A 24 logical cursor at 150% targets 36 px,
        // but the nearest bitmap is 32 px: draw it at 32 px (21 logical)
        // rather than stretching it to 36 and blurring it.
        let placement = native_cursor_placement(&test_icon(32), 1.5);
        assert_eq!(placement.logical_size, Size::from((21, 21)));
        assert_eq!((f64::from(placement.logical_size.w) * 1.5).round(), 32.0);
    }
}
