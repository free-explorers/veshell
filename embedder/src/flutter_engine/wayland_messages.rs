use smithay::utils::{Buffer as BufferCoords, Logical, Point, Rectangle, Size};
use smithay::wayland::compositor;
use smithay::wayland::compositor::{RectangleKind, RegionAttributes};
use smithay::wayland::shell::xdg;

use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;

#[derive(Debug)]
pub struct SurfaceCommitMessage {
    pub surface_id: u64,
    pub role: Option<&'static str>,
    pub texture_id: i64,
    pub buffer_delta: Option<Point<i32, Logical>>,
    pub buffer_size: Option<Size<i32, BufferCoords>>,
    pub scale: i32,
    pub input_region: Option<RegionAttributes>,
    pub xdg_surface: Option<XdgSurfaceCommitMessage>,
    pub xdg_popup: Option<XdgPopupCommitMessage>,
    pub subsurface: Option<SubsurfaceCommitMessage>,
    pub subsurfaces_below: Vec<u64>,
    pub subsurfaces_above: Vec<u64>,
}

#[derive(Debug)]
pub struct XdgSurfaceCommitMessage {
    pub role: Option<&'static str>,
    pub geometry: Option<Rectangle<i32, Logical>>,
}

#[derive(Debug)]
pub struct XdgPopupCommitMessage {
    pub parent_id: u64,
    pub geometry: Rectangle<i32, Logical>,
}

#[derive(Debug)]
pub struct SubsurfaceCommitMessage {
    pub location: Point<i32, Logical>,
}

impl SurfaceCommitMessage {
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
                EncodableValue::String("surface".to_string()),
                EncodableValue::Map(vec![
                    (
                        EncodableValue::String("role".to_string()),
                        EncodableValue::Int64(
                            self.role
                                .map(|role| match role {
                                    xdg::XDG_TOPLEVEL_ROLE | xdg::XDG_POPUP_ROLE => 1,
                                    compositor::SUBSURFACE_ROLE => 2,
                                    _ => 0,
                                })
                                .unwrap_or(0),
                        ),
                    ),
                    (
                        EncodableValue::String("textureId".to_string()),
                        EncodableValue::Int64(self.texture_id),
                    ),
                    (
                        EncodableValue::String("x".to_string()),
                        EncodableValue::Int32(0),
                    ),
                    (
                        EncodableValue::String("y".to_string()),
                        EncodableValue::Int32(0),
                    ),
                    (
                        EncodableValue::String("width".to_string()),
                        EncodableValue::Int32(self.buffer_size.map(|size| size.w).unwrap_or(0)),
                    ),
                    (
                        EncodableValue::String("height".to_string()),
                        EncodableValue::Int32(self.buffer_size.map(|size| size.h).unwrap_or(0)),
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
                                EncodableValue::String("x1".to_string()),
                                EncodableValue::Int32(input_region.loc.x),
                            ),
                            (
                                EncodableValue::String("y1".to_string()),
                                EncodableValue::Int32(input_region.loc.y),
                            ),
                            (
                                EncodableValue::String("x2".to_string()),
                                EncodableValue::Int32(input_region.loc.x + input_region.size.w),
                            ),
                            (
                                EncodableValue::String("y2".to_string()),
                                EncodableValue::Int32(input_region.loc.y + input_region.size.h),
                            ),
                        ]),
                    ),
                ]),
            ),
        ];

        if let Some(subsurface) = self.subsurface {
            vec.push((
                EncodableValue::String("subsurface".to_string()),
                subsurface.serialize(),
            ));
        }

        if let Some(xdg_surface) = self.xdg_surface {
            vec.push((
                EncodableValue::String("xdgSurface".to_string()),
                xdg_surface.serialize(),
            ));

            if let Some(xdg_popup) = self.xdg_popup {
                vec.push((
                    EncodableValue::String("xdgPopup".to_string()),
                    xdg_popup.serialize(),
                ));
            }
        }

        EncodableValue::Map(vec)
    }
}

impl XdgSurfaceCommitMessage {
    pub fn serialize(self) -> EncodableValue {
        EncodableValue::Map(vec![
            (
                EncodableValue::String("role".to_string()),
                EncodableValue::Int64(
                    self.role
                        .map(|role| match role {
                            xdg::XDG_TOPLEVEL_ROLE => 1,
                            xdg::XDG_POPUP_ROLE => 2,
                            _ => 0,
                        })
                        .unwrap_or(0),
                ),
            ),
            (
                EncodableValue::String("x".to_string()),
                EncodableValue::Int64(
                    self.geometry.map(|geometry| geometry.loc.x).unwrap_or(0) as i64
                ),
            ),
            (
                EncodableValue::String("y".to_string()),
                EncodableValue::Int64(
                    self.geometry.map(|geometry| geometry.loc.y).unwrap_or(0) as i64
                ),
            ),
            (
                EncodableValue::String("width".to_string()),
                EncodableValue::Int64(
                    self.geometry.map(|geometry| geometry.size.w).unwrap_or(0) as i64
                ),
            ),
            (
                EncodableValue::String("height".to_string()),
                EncodableValue::Int64(
                    self.geometry.map(|geometry| geometry.size.h).unwrap_or(0) as i64
                ),
            ),
        ])
    }
}

impl XdgPopupCommitMessage {
    pub fn serialize(self) -> EncodableValue {
        EncodableValue::Map(vec![
            (
                EncodableValue::String("parentId".to_string()),
                EncodableValue::Int64(self.parent_id as i64),
            ),
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
        ])
    }
}

impl SubsurfaceCommitMessage {
    pub fn serialize(self) -> EncodableValue {
        EncodableValue::Map(vec![
            (
                EncodableValue::String("x".to_string()),
                EncodableValue::Int64(self.location.x as i64),
            ),
            (
                EncodableValue::String("y".to_string()),
                EncodableValue::Int64(self.location.y as i64),
            ),
        ])
    }
}
