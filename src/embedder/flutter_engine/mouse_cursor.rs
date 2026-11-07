//! https://api.flutter.dev/flutter/services/SystemChannels/mouseCursor-constant.html

use smithay::input::pointer::CursorIcon;
use smithay::reexports::calloop::channel::Event;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

use super::platform_channels::encodable_value::EncodableValue;

/// Maps a Flutter `SystemMouseCursor` kind to the cursor theme shape.
///
/// Kinds without a themed equivalent fall back to the default arrow.
pub(crate) fn cursor_icon_for_kind(kind: &str) -> CursorIcon {
    match kind {
        "basic" => CursorIcon::Default,
        "click" => CursorIcon::Pointer,
        "forbidden" => CursorIcon::NotAllowed,
        "wait" => CursorIcon::Wait,
        "progress" => CursorIcon::Progress,
        "contextMenu" => CursorIcon::ContextMenu,
        "help" => CursorIcon::Help,
        "text" => CursorIcon::Text,
        "verticalText" => CursorIcon::VerticalText,
        "cell" => CursorIcon::Cell,
        "precise" => CursorIcon::Crosshair,
        "move" => CursorIcon::Move,
        "grab" => CursorIcon::Grab,
        "grabbing" => CursorIcon::Grabbing,
        "noDrop" => CursorIcon::NoDrop,
        "alias" => CursorIcon::Alias,
        "copy" => CursorIcon::Copy,
        "allScroll" => CursorIcon::AllScroll,
        "resizeLeftRight" => CursorIcon::EwResize,
        "resizeUpDown" => CursorIcon::NsResize,
        "resizeUpLeftDownRight" => CursorIcon::NwseResize,
        "resizeUpRightDownLeft" => CursorIcon::NeswResize,
        "resizeUp" => CursorIcon::NResize,
        "resizeDown" => CursorIcon::SResize,
        "resizeLeft" => CursorIcon::WResize,
        "resizeRight" => CursorIcon::EResize,
        "resizeUpLeft" => CursorIcon::NwResize,
        "resizeUpRight" => CursorIcon::NeResize,
        "resizeDownLeft" => CursorIcon::SwResize,
        "resizeDownRight" => CursorIcon::SeResize,
        "resizeColumn" => CursorIcon::ColResize,
        "resizeRow" => CursorIcon::RowResize,
        "zoomIn" => CursorIcon::ZoomIn,
        "zoomOut" => CursorIcon::ZoomOut,
        // `disappearing` and unknown kinds have no themed shape.
        _ => CursorIcon::Default,
    }
}

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
        // Sent by the shell while a tile row or workspace slides: Flutter
        // reports the arrow as the page under the pointer leaves the hit test,
        // which must not replace the shape the pointer had before the slide.
        if method_call.method() == "setCursorTransitioning" {
            let transitioning = arguments
                .and_then(|arguments| arguments.map())
                .and_then(|arguments| {
                    arguments.iter().find_map(|(key, value)| {
                        (key.string() == Some("transitioning"))
                            .then(|| value.bool())
                            .flatten()
                    })
                })
                .unwrap_or(false);
            let changed = data
                .cursor_state
                .lock()
                .unwrap()
                .set_transitioning(transitioning);
            if changed {
                data.request_render();
            }
            return result.success(None);
        }
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
                let changed = data
                    .cursor_state
                    .lock()
                    .unwrap()
                    .set_flutter_shape(cursor_icon_for_kind(kind));
                // Rendering is on demand. Flutter reports the cursor after the
                // pointer event that caused it, often after that event's frame
                // already composited, so without a render the new shape would
                // only show on the next unrelated repaint.
                if changed {
                    data.request_render();
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_interactive_kinds_to_their_shapes() {
        assert_eq!(cursor_icon_for_kind("click"), CursorIcon::Pointer);
        assert_eq!(cursor_icon_for_kind("grabbing"), CursorIcon::Grabbing);
        assert_eq!(cursor_icon_for_kind("resizeColumn"), CursorIcon::ColResize);
        assert_eq!(cursor_icon_for_kind("resizeRow"), CursorIcon::RowResize);
        assert_eq!(cursor_icon_for_kind("allScroll"), CursorIcon::AllScroll);
    }

    #[test]
    fn unknown_kinds_fall_back_to_the_arrow() {
        assert_eq!(cursor_icon_for_kind("disappearing"), CursorIcon::Default);
        assert_eq!(cursor_icon_for_kind("no-such-kind"), CursorIcon::Default);
    }
}
