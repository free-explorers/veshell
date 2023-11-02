use smithay::utils::{Buffer as BufferCoords, Logical, Point, Rectangle, Size};
use smithay::wayland::compositor;
use smithay::wayland::compositor::RegionAttributes;
use smithay::wayland::shell::xdg;

use crate::flutter_engine::platform_channels::encodable_value::EncodableValue;

pub struct SurfaceCommitMessage {
    pub view_id: u64,
    pub role: Option<&'static str>,
    pub texture_id: i64,
    pub buffer_delta: Option<Point<i32, Logical>>,
    pub buffer_size: Option<Size<i32, BufferCoords>>,
    pub scale: i32,
    pub input_region: Option<RegionAttributes>,
    pub xdg_surface: Option<XdgSurfaceCommitMessage>,
}

pub struct XdgSurfaceCommitMessage {
    pub mapped: bool,
    pub role: Option<&'static str>,
    pub geometry: Option<Rectangle<i32, Logical>>,
}

impl SurfaceCommitMessage {
    pub fn serialize(self) -> EncodableValue {
        let mut vec = vec![
            (EncodableValue::String("view_id".to_string()), EncodableValue::Int64(self.view_id as i64)),
            (EncodableValue::String("surface".to_string()), EncodableValue::Map(vec![
                (EncodableValue::String("role".to_string()), EncodableValue::Int64(self.role.map(|role| {
                    match role {
                        xdg::XDG_TOPLEVEL_ROLE | xdg::XDG_POPUP_ROLE => 1,
                        compositor::SUBSURFACE_ROLE => 2,
                        _ => 0,
                    }
                }).unwrap_or(0))),
                (EncodableValue::String("textureId".to_string()), EncodableValue::Int64(self.texture_id as i64)),
                (EncodableValue::String("x".to_string()), EncodableValue::Int32(self.buffer_delta.map(|delta| delta.x).unwrap_or(0))),
                (EncodableValue::String("y".to_string()), EncodableValue::Int32(self.buffer_delta.map(|delta| delta.y).unwrap_or(0))),
                (EncodableValue::String("width".to_string()), EncodableValue::Int32(self.buffer_size.map(|size| size.w).unwrap_or(0))),
                (EncodableValue::String("height".to_string()), EncodableValue::Int32(self.buffer_size.map(|size| size.h).unwrap_or(0))),
                (EncodableValue::String("scale".to_string()), EncodableValue::Int32(self.scale)),
                (EncodableValue::String("subsurfaces_below".to_string()), EncodableValue::List(vec![])),
                (EncodableValue::String("subsurfaces_above".to_string()), EncodableValue::List(vec![])),
                (EncodableValue::String("input_region".to_string()), EncodableValue::Map(vec![
                    // TODO
                    (EncodableValue::String("x1".to_string()), EncodableValue::Int64(self.buffer_delta.map(|delta| delta.x).unwrap_or(0) as i64)),
                    (EncodableValue::String("y1".to_string()), EncodableValue::Int64(self.buffer_delta.map(|delta| delta.y).unwrap_or(0) as i64)),
                    (EncodableValue::String("x2".to_string()), EncodableValue::Int64(self.buffer_size.map(|size| size.w).unwrap_or(0) as i64)),
                    (EncodableValue::String("y2".to_string()), EncodableValue::Int64(self.buffer_size.map(|size| size.h).unwrap_or(0) as i64)),
                ])),
            ])),
        ];

        if let Some(xdg_surface) = self.xdg_surface {
            vec.extend([
                (EncodableValue::String("has_xdg_surface".to_string()), EncodableValue::Bool(true)),
                (EncodableValue::String("xdg_surface".to_string()), xdg_surface.serialize()),
                (EncodableValue::String("has_xdg_popup".to_string()), EncodableValue::Bool(false)),
                (EncodableValue::String("has_toplevel_decoration".to_string()), EncodableValue::Bool(false)),
                (EncodableValue::String("has_toplevel_title".to_string()), EncodableValue::Bool(false)),
                (EncodableValue::String("has_toplevel_app_id".to_string()), EncodableValue::Bool(false)),
            ]);
        } else {
            vec.push(
                (EncodableValue::String("has_xdg_surface".to_string()), EncodableValue::Bool(false)),
            )
        }

        EncodableValue::Map(vec)
    }
}

impl XdgSurfaceCommitMessage {
    pub fn serialize(self) -> EncodableValue {
        EncodableValue::Map(vec![
            (EncodableValue::String("mapped".to_string()), EncodableValue::Bool(self.mapped)),
            (EncodableValue::String("role".to_string()), EncodableValue::Int64(self.role.map(|role| {
                match role {
                    xdg::XDG_TOPLEVEL_ROLE => 1,
                    xdg::XDG_POPUP_ROLE => 2,
                    _ => 0,
                }
            }).unwrap_or(0))),
            (EncodableValue::String("x".to_string()), EncodableValue::Int64(self.geometry.map(|geometry| geometry.loc.x).unwrap_or(0) as i64)),
            (EncodableValue::String("y".to_string()), EncodableValue::Int64(self.geometry.map(|geometry| geometry.loc.y).unwrap_or(0) as i64)),
            (EncodableValue::String("width".to_string()), EncodableValue::Int64(self.geometry.map(|geometry| geometry.size.w).unwrap_or(0) as i64)),
            (EncodableValue::String("height".to_string()), EncodableValue::Int64(self.geometry.map(|geometry| geometry.size.h).unwrap_or(0) as i64)),
        ])
    }
}
