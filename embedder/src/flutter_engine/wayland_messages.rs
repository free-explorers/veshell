use smithay::utils::{Buffer as BufferCoords, Logical, Point, Rectangle, Size};
use smithay::wayland::compositor;
use smithay::wayland::compositor::{RectangleKind, RegionAttributes};
use smithay::wayland::shell::xdg;

use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;

#[derive(Debug)]
pub struct SurfaceMessage {
    pub surface_id: u64,
    pub role: Option<&'static str>,
    pub texture_id: i64,
    pub buffer_delta: Option<Point<i32, Logical>>,
    pub buffer_size: Option<Size<i32, BufferCoords>>,
    pub scale: i32,
    pub input_region: Option<RegionAttributes>,
    pub subsurfaces_below: Vec<u64>,
    pub subsurfaces_above: Vec<u64>,
}

impl SurfaceMessage {
    pub fn serialize(self) -> EncodableValue {
        // TODO: Serialize all the rectangles instead of merging them into one.
        let input_region = if let Some(input_region) = self.input_region {
            let mut acc: Option<Rectangle<i32, Logical>> = None;
            for (kind, rect) in input_region.rects {
                if let RectangleKind::Add = kind {
                    if let Some(acc_) = acc {
                        acc = Some(acc_.merge(rect));
                    } else {
                        acc = Some(rect);
                    }
                }
            }
            acc.unwrap_or_default()
        } else {
            // TODO: Account for DPI scaling.
            self.buffer_size
                .map(|size| Rectangle::from_loc_and_size((0, 0), (size.w, size.h)))
                .unwrap_or_default()
        };

        let mut vec = vec![
            (
                EncodableValue::String("surfaceId".to_string()),
                EncodableValue::Int64(self.surface_id as i64),
            ),
            (
                EncodableValue::String("role".to_string()),
                EncodableValue::String(
                    self.role
                        .map(|role| role.to_string())
                        .unwrap_or("".to_string()),
                ),
            ),
            (
                EncodableValue::String("textureId".to_string()),
                EncodableValue::Int64(self.texture_id),
            ),
            (
                EncodableValue::String("bufferDelta".to_string()),
                self.buffer_delta
                    .map(|delta| {
                        EncodableValue::Map(vec![
                            (
                                EncodableValue::String("x".to_string()),
                                EncodableValue::Int64(delta.x as i64),
                            ),
                            (
                                EncodableValue::String("y".to_string()),
                                EncodableValue::Int64(delta.y as i64),
                            ),
                        ])
                    })
                    .unwrap_or(EncodableValue::Null),
            ),
            (
                EncodableValue::String("bufferSize".to_string()),
                self.buffer_size
                    .map(|size| {
                        EncodableValue::Map(vec![
                            (
                                EncodableValue::String("width".to_string()),
                                EncodableValue::Int64(size.w as i64),
                            ),
                            (
                                EncodableValue::String("height".to_string()),
                                EncodableValue::Int64(size.h as i64),
                            ),
                        ])
                    })
                    .unwrap_or(EncodableValue::Null),
            ),
            (
                EncodableValue::String("scale".to_string()),
                EncodableValue::Int32(self.scale),
            ),
            (
                EncodableValue::String("subsurfacesBelow".to_string()),
                EncodableValue::List(
                    self.subsurfaces_below
                        .into_iter()
                        .map(|id| EncodableValue::Int64(id as i64))
                        .collect(),
                ),
            ),
            (
                EncodableValue::String("subsurfacesAbove".to_string()),
                EncodableValue::List(
                    self.subsurfaces_above
                        .into_iter()
                        .map(|id| EncodableValue::Int64(id as i64))
                        .collect(),
                ),
            ),
            (
                EncodableValue::String("inputRegion".to_string()),
                EncodableValue::Map(vec![
                    (
                        EncodableValue::String("x".to_string()),
                        EncodableValue::Int32(input_region.loc.x),
                    ),
                    (
                        EncodableValue::String("y".to_string()),
                        EncodableValue::Int32(input_region.loc.y),
                    ),
                    (
                        EncodableValue::String("width".to_string()),
                        EncodableValue::Int32(input_region.size.w),
                    ),
                    (
                        EncodableValue::String("height".to_string()),
                        EncodableValue::Int32(input_region.size.h),
                    ),
                ]),
            ),
        ];

        EncodableValue::Map(vec)
    }
}

#[derive(Debug)]
pub struct ToplevelMessage {
    pub surface_id: u64,
    pub role: &'static str,
    pub app_id: String,
    pub title: String,
    pub geometry: Option<Rectangle<i32, Logical>>,
    pub surface: SurfaceMessage,
    pub parent_surface_id: Option<u64>,
}

impl ToplevelMessage {
    pub fn serialize(self) -> EncodableValue {
        let mut map = vec![
            (
                EncodableValue::String("surfaceId".to_string()),
                EncodableValue::Int64(self.surface_id as i64),
            ),
            (
                EncodableValue::String("role".to_string()),
                EncodableValue::String(self.role.to_string()),
            ),
            (
                EncodableValue::String("appId".to_string()),
                EncodableValue::String(self.app_id),
            ),
            (
                EncodableValue::String("title".to_string()),
                EncodableValue::String(self.title),
            ),
            (
                EncodableValue::String("surface".to_string()),
                self.surface.serialize(),
            ),
        ];

        map.extend(self.geometry.map(|geometry| {
            (
                EncodableValue::String("geometry".to_string()),
                EncodableValue::Map(vec![
                    (
                        EncodableValue::String("x".to_string()),
                        EncodableValue::Int64(geometry.loc.x as i64),
                    ),
                    (
                        EncodableValue::String("y".to_string()),
                        EncodableValue::Int64(geometry.loc.y as i64),
                    ),
                    (
                        EncodableValue::String("width".to_string()),
                        EncodableValue::Int64(geometry.size.w as i64),
                    ),
                    (
                        EncodableValue::String("height".to_string()),
                        EncodableValue::Int64(geometry.size.h as i64),
                    ),
                ]),
            )
        }));

        if let Some(parent_surface_id) = self.parent_surface_id {
            map.push((
                EncodableValue::String("parentSurfaceId".to_string()),
                EncodableValue::Int64(parent_surface_id as i64),
            ));
        }

        EncodableValue::Map(map)
    }
}

#[derive(Debug)]
pub struct PopupMessage {
    pub surface_id: u64,
    pub role: &'static str,
    pub geometry: Rectangle<i32, Logical>,
    pub surface: SurfaceMessage,
    pub parent_surface_id: u64,
}

impl PopupMessage {
    pub fn serialize(self) -> EncodableValue {
        let mut map = vec![
            (
                EncodableValue::String("surfaceId".to_string()),
                EncodableValue::Int64(self.surface_id as i64),
            ),
            (
                EncodableValue::String("role".to_string()),
                EncodableValue::String(self.role.to_string()),
            ),
            (
                EncodableValue::String("surface".to_string()),
                self.surface.serialize(),
            ),
            (
                EncodableValue::String("parentSurfaceId".to_string()),
                EncodableValue::Int64(self.parent_surface_id as i64),
            ),
            (
                EncodableValue::String("geometry".to_string()),
                EncodableValue::Map(vec![
                    (
                        EncodableValue::String("x".to_string()),
                        EncodableValue::Int64(self.geometry.loc.x as i64),
                    ),
                    (
                        EncodableValue::String("y".to_string()),
                        EncodableValue::Int64(self.geometry.loc.y as i64),
                    ),
                    (
                        EncodableValue::String("width".to_string()),
                        EncodableValue::Int64(self.geometry.size.w as i64),
                    ),
                    (
                        EncodableValue::String("height".to_string()),
                        EncodableValue::Int64(self.geometry.size.h as i64),
                    ),
                ]),
            ),
        ];

        EncodableValue::Map(map)
    }
}

#[derive(Debug)]
pub struct SubsurfaceMessage {
    pub surface_id: u64,
    pub role: &'static str,
    pub position: Point<i32, Logical>,
    pub surface: SurfaceMessage,
    pub parent_surface_id: u64,
}

impl SubsurfaceMessage {
    pub fn serialize(self) -> EncodableValue {
        let mut map = vec![
            (
                EncodableValue::String("surfaceId".to_string()),
                EncodableValue::Int64(self.surface_id as i64),
            ),
            (
                EncodableValue::String("role".to_string()),
                EncodableValue::String(self.role.to_string()),
            ),
            (
                EncodableValue::String("position".to_string()),
                EncodableValue::Map(vec![
                    (
                        EncodableValue::String("x".to_string()),
                        EncodableValue::Int64(self.position.x as i64),
                    ),
                    (
                        EncodableValue::String("y".to_string()),
                        EncodableValue::Int64(self.position.y as i64),
                    ),
                ]),
            ),
            (
                EncodableValue::String("surface".to_string()),
                self.surface.serialize(),
            ),
            (
                EncodableValue::String("parentSurfaceId".to_string()),
                EncodableValue::Int64(self.parent_surface_id as i64),
            ),
        ];
        EncodableValue::Map(map)
    }
}
