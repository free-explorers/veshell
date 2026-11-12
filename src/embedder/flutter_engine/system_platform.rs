//! The framework's own `flutter/platform` channel (`SystemChannels.platform`):
//! the clipboard behind the shell's copy and paste. Other methods (system
//! sounds, haptics, ...) have no meaning in a compositor and are reported
//! as not implemented, which the framework tolerates.

use serde_json::{json, Value};
use smithay::reexports::calloop::channel::Event;
use std::sync::Arc;

use crate::backend::Backend;
use crate::clipboard::{
    clipboard_has_text, read_clipboard_text, set_native_clipboard, NativeSelection,
};
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

pub fn system_platform_channel_method_handler<BackendData: Backend + 'static>(
    event: Event<(MethodCall<Value>, Box<dyn MethodResult<Value>>)>,
    _: &mut (),
    data: &mut State<BackendData>,
) {
    let Event::Msg((method_call, mut result)) = event else {
        return;
    };
    match method_call.method() {
        // `{"text": "..."}`: the shell copied (or cut) text.
        "Clipboard.setData" => {
            let text = method_call
                .arguments()
                .and_then(|arguments| arguments.get("text"))
                .and_then(Value::as_str);
            if let Some(text) = text {
                set_native_clipboard(data, NativeSelection::Text(Arc::new(text.to_owned())));
            }
            result.success(None);
        }
        // `"text/plain"`, the only format the framework asks for: answer
        // `{"text": "..."}`, or null when there is no text to paste.
        "Clipboard.getData" => read_clipboard_text(data, move |text| {
            result.success(text.map(|text| json!({ "text": text })));
        }),
        // Whether a paste would find text: enables the "Paste" action.
        "Clipboard.hasStrings" => {
            result.success(Some(json!({ "value": clipboard_has_text(data) })));
        }
        _ => result.not_implemented(),
    }
}
