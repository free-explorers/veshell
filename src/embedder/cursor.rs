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
    utils::{Buffer as BufferCoords, IsAlive, Logical, Monotonic, Point, Size, Time, Transform},
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
    size: u32,
}

impl Cursor {
    pub fn load(theme: &CursorTheme, shape: CursorIcon, size: u32) -> Cursor {
        let icons = load_icon(&theme, shape)
            .map_err(|err| warn!(?err, "Unable to load xcursor, using fallback cursor"))
            .or_else(|_| load_icon(&theme, CursorIcon::Default))
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

        Cursor { icons, size }
    }

    pub fn get_image(&self, scale: u32, millis: u32) -> Image {
        let size = self.size * scale;
        frame(millis, size, &self.icons)
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
            .or_insert_with(|| Cursor::load(&self.cursor_theme, shape, self.cursor_size))
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
) -> Vec<(CursorRenderElement<R>, Point<i32, BufferCoords>)>
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
        let integer_scale = scale.integer_scale();
        let frame = state
            .get_named_cursor(current_cursor)
            .get_image(integer_scale as u32, time.as_millis());

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
                    integer_scale as i32,
                    Transform::Normal,
                    None,
                );
                pointer_images.push((frame.clone(), buffer));
                pointer_images.last().map(|(_, i)| i).unwrap()
            }
        };

        let hotspot = Point::<i32, BufferCoords>::from((frame.xhot as i32, frame.yhot as i32));
        state.current_image = Some(frame);
        let float_scale: utils::Scale<f64> = scale.fractional_scale().into();
        return vec![(
            CursorRenderElement::Static(
                MemoryRenderBufferRenderElement::from_buffer(
                    renderer,
                    location.to_physical_precise_round(float_scale),
                    &pointer_image,
                    None,
                    None,
                    None,
                    Kind::Cursor,
                )
                .expect("Failed to import cursor bitmap"),
            ),
            hotspot,
        )];
    } else {
        Vec::new()
    }
}

pub fn draw_surface_cursor<R>(
    renderer: &mut R,
    surface: &WlSurface,
    location: impl Into<Point<i32, Logical>>,
    scale: utils::Scale<f64>,
) -> Vec<(CursorRenderElement<R>, Point<i32, BufferCoords>)>
where
    R: Renderer + ImportAll,
    <R as RendererSuper>::TextureId: Clone + 'static,
{
    let position = location.into();
    let h: Point<i32, BufferCoords> = with_states(&surface, |states| {
        states
            .data_map
            .get::<Mutex<CursorImageAttributes>>()
            .unwrap()
            .lock()
            .unwrap()
            .hotspot
            .to_buffer(
                1,
                Transform::Normal,
                &Size::from((1, 1)), /* Size doesn't matter for Transform::Normal */
            )
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
}
