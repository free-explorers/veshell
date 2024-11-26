use std::{collections::HashMap, io::Read, sync::Mutex, time::Duration};

use smithay::backend::renderer::gles::GlesRenderer;
use smithay::{
    backend::{
        allocator::Fourcc,
        renderer::{
            element::{
                memory::{MemoryRenderBuffer, MemoryRenderBufferRenderElement},
                surface::{self, render_elements_from_surface_tree, WaylandSurfaceRenderElement},
                texture::{TextureBuffer, TextureRenderElement},
                Id, Kind,
            },
            gles::GlesTexture,
            ImportAll, ImportMem, Renderer,
        },
    },
    input::pointer::{CursorIcon, CursorImageAttributes, CursorImageStatus},
    reexports::wayland_server::protocol::wl_surface::{self, WlSurface},
    render_elements,
    utils::{
        Buffer as BufferCoords, IsAlive, Logical, Monotonic, Point, Scale, Size, Time, Transform,
    },
    wayland::compositor::with_states,
};
use tracing::{info, warn};
use xcursor::{
    parser::{parse_xcursor, Image},
    CursorTheme,
};

static FALLBACK_CURSOR_DATA: &[u8] = include_bytes!("../resources/cursor.rgba");

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
    pub CursorRenderElement<=GlesRenderer>;
    Static=MemoryRenderBufferRenderElement<GlesRenderer>,
    Texture=TextureRenderElement<<GlesRenderer as Renderer>::TextureId>,
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
    current_cursor: Option<CursorIcon>,

    cursor_theme: CursorTheme,
    cursor_size: u32,

    cursors: HashMap<CursorIcon, Cursor>,
    current_image: Option<Image>,
    current_surface_texture: Option<GlesTexture>,
    current_surface_texture_id: Option<i64>,
    image_cache: Vec<(Image, MemoryRenderBuffer)>,
}

impl CursorStateInner {
    pub fn set_shape(&mut self, shape: CursorIcon) {
        self.current_cursor = Some(shape);
    }

    pub fn unset_shape(&mut self) {
        self.current_cursor = None;
    }

    pub fn set_surface_texture(&mut self, texture_id: i64, surface_texture: GlesTexture) {
        self.current_surface_texture_id = Some(texture_id);
        self.current_surface_texture = Some(surface_texture);
    }

    pub fn get_named_cursor(&mut self, shape: CursorIcon) -> &Cursor {
        self.cursors
            .entry(shape)
            .or_insert_with(|| Cursor::load(&self.cursor_theme, shape, self.cursor_size))
    }
}

pub fn load_cursor_theme() -> (CursorTheme, u32) {
    let name = std::env::var("XCURSOR_THEME")
        .ok()
        .unwrap_or_else(|| "default".into());
    let size = std::env::var("XCURSOR_SIZE")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(24);
    (CursorTheme::load(&name), size)
}

impl Default for CursorStateInner {
    fn default() -> CursorStateInner {
        let (theme, size) = load_cursor_theme();
        CursorStateInner {
            current_cursor: None,

            cursor_size: size,
            cursor_theme: theme,

            cursors: HashMap::new(),
            current_image: None,
            current_surface_texture_id: None,
            current_surface_texture: None,
            image_cache: Vec::new(),
        }
    }
}

pub fn draw_cursor(
    renderer: &mut GlesRenderer,
    cursor_image_status: &Mutex<CursorImageStatus>,
    cursor_state: &Mutex<CursorStateInner>,
    scale: Scale<f64>,
    time: Time<Monotonic>,
    location: Point<f64, Logical>,
    is_surface_under_pointer: bool,
) -> Vec<(CursorRenderElement, Point<i32, BufferCoords>)> {
    let cursor_status = {
        let cursor_image_status = cursor_image_status.lock().unwrap();

        match *cursor_image_status {
            CursorImageStatus::Surface(ref surface) if !surface.alive() => {
                CursorImageStatus::default_named()
            }
            ref status => status.clone(),
        }
    };

    info!("draw_cursor {:?}", cursor_status);

    let mut state_ref = cursor_state.lock().unwrap();
    let state = &mut *state_ref;

    let named_cursor = state.current_cursor.or(match cursor_status {
        CursorImageStatus::Named(named_cursor) => Some(named_cursor),
        _ => None,
    });
    let texture = state.current_surface_texture.clone();

    if let CursorImageStatus::Surface(ref wl_surface) = cursor_status {
        if is_surface_under_pointer && texture.is_some() {
            return draw_surface_cursor(
                renderer,
                wl_surface,
                state.current_surface_texture_id.clone().unwrap(),
                texture.unwrap(),
                location.to_i32_round(),
                scale,
            );
        }
    }
    if let Some(current_cursor) = named_cursor {
        let integer_scale = scale.x.max(scale.y).ceil() as u32;
        let frame = state
            .get_named_cursor(current_cursor)
            .get_image(integer_scale, time.as_millis());

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

        return vec![(
            CursorRenderElement::Static(
                MemoryRenderBufferRenderElement::from_buffer(
                    renderer,
                    location.to_physical(scale),
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

pub fn draw_surface_cursor(
    renderer: &mut GlesRenderer,
    surface: &WlSurface,
    texture_id: i64,
    texture: GlesTexture,
    location: impl Into<Point<i32, Logical>>,
    scale: Scale<f64>,
) -> Vec<(CursorRenderElement, Point<i32, BufferCoords>)> {
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

    let location = position.to_physical_precise_round(scale);
    let integer_scale = scale.x.max(scale.y).ceil() as i32;

    let render_element = TextureRenderElement::from_static_texture(
        Id::new(),
        renderer.id(),
        location,
        texture,
        integer_scale,
        Transform::Normal,
        None,
        None,
        None,
        None,
        Kind::Cursor,
    );

    Vec::from([(CursorRenderElement::Texture(render_element), h)])
}
