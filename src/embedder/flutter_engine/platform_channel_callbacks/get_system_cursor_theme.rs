use serde_json::json;

use crate::backend::Backend;
use crate::cursor::system_cursor_theme_label;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

/// Return the cursor theme an empty `theme.cursorTheme` ("System default")
/// draws with, so the picker can name and preview it.
pub fn get_system_cursor_theme<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    _data: &mut State<BackendData>,
) {
    result.success(Some(json!({ "theme": system_cursor_theme_label() })));
}
