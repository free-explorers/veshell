//! https://api.flutter.dev/flutter/services/SystemChannels/textInput-constant.html

use smithay::input::pointer::CursorIcon;
use smithay::reexports::calloop::channel::Event;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

use super::platform_channels::encodable_value::EncodableValue;

pub fn mouse_cursor_channel_method_call_handler<BackendData: Backend + 'static>(
    event: Event<(
        MethodCall<EncodableValue>,
        Box<dyn MethodResult<EncodableValue>>,
    )>,
    _: &mut (),
    data: &mut State<BackendData>,
) {
    if let Event::Msg((method_call, mut result)) = event {
        let arguments = method_call.arguments();
        if method_call.method() == "activateSystemCursor" {
            let args = arguments.unwrap().map().unwrap();
            let mut kind = None;
            let mut device: Option<i32> = None;
            for (key, value) in args.iter() {
                let key_string = key.string().unwrap();
                if key_string == "kind" {
                    kind = value.string();
                }
                if key_string == "device" {
                    device = value.int32();
                }
            }
            if let (Some(kind), Some(_device)) = (kind, device) {
                let mut cursor_state = data.cursor_state.lock().unwrap();
                match kind {
                    "basic" => cursor_state.set_shape(CursorIcon::Default),
                    "click" => cursor_state.set_shape(CursorIcon::Pointer),
                    "forbidden" => cursor_state.set_shape(CursorIcon::NotAllowed),
                    "wait" => cursor_state.set_shape(CursorIcon::Wait),
                    "progress" => cursor_state.set_shape(CursorIcon::Progress),
                    "contextMenu" => cursor_state.set_shape(CursorIcon::ContextMenu),
                    "help" => cursor_state.set_shape(CursorIcon::Help),
                    "text" => cursor_state.set_shape(CursorIcon::Text),
                    "verticalText" => cursor_state.set_shape(CursorIcon::VerticalText),
                    "cell" => cursor_state.set_shape(CursorIcon::Cell),
                    "precise" => cursor_state.set_shape(CursorIcon::Crosshair),
                    "move" => cursor_state.set_shape(CursorIcon::Move),
                    "grab" => cursor_state.set_shape(CursorIcon::Grab),
                    "grabbing" => cursor_state.set_shape(CursorIcon::Grabbing),
                    "noDrop" => cursor_state.set_shape(CursorIcon::NoDrop),
                    "alias" => cursor_state.set_shape(CursorIcon::Alias),
                    "copy" => cursor_state.set_shape(CursorIcon::Copy),
                    "disappearing" => cursor_state.set_shape(CursorIcon::Default), // No direct equivalent
                    "allScroll" => cursor_state.set_shape(CursorIcon::Default), // No direct equivalent
                    "resizeLeftRight" => cursor_state.set_shape(CursorIcon::EwResize),
                    "resizeUpDown" => cursor_state.set_shape(CursorIcon::NsResize),
                    "resizeUpLeftDownRight" => cursor_state.set_shape(CursorIcon::NwseResize),
                    "resizeUpRightDownLeft" => cursor_state.set_shape(CursorIcon::NeswResize),
                    "resizeUp" => cursor_state.set_shape(CursorIcon::NResize),
                    "resizeDown" => cursor_state.set_shape(CursorIcon::SResize),
                    "resizeLeft" => cursor_state.set_shape(CursorIcon::WResize),
                    "resizeRight" => cursor_state.set_shape(CursorIcon::EResize),
                    "resizeUpLeft" => cursor_state.set_shape(CursorIcon::NwResize),
                    "resizeUpRight" => cursor_state.set_shape(CursorIcon::NeResize),
                    "resizeDownLeft" => cursor_state.set_shape(CursorIcon::SwResize),
                    "resizeDownRight" => cursor_state.set_shape(CursorIcon::SeResize),
                    "resizeColumn" => cursor_state.set_shape(CursorIcon::NeswResize), // No direct equivalent
                    "resizeRow" => cursor_state.set_shape(CursorIcon::NeswResize), // No direct equivalent
                    "zoomIn" => cursor_state.set_shape(CursorIcon::ZoomIn),
                    "zoomOut" => cursor_state.set_shape(CursorIcon::ZoomOut),
                    _ => cursor_state.set_shape(CursorIcon::Default),
                }

                return result.success(None);
            }
            return result.error(
                "no_device_or_kind".to_string(),
                "No device or kind provided".to_string(),
                None,
            );
        }
        return result.not_implemented();
    }
}
