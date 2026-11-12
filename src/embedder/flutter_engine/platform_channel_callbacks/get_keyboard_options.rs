use serde_json::json;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::keyboard::xkb_registry::list_keyboard_options;
use crate::state::State;

/// Return the xkb option catalogue, grouped, read from libxkbregistry. The
/// shell backs its keyboard-options picker with this, so it only offers
/// options the seat keymap knows.
pub fn get_keyboard_options<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    _data: &mut State<BackendData>,
) {
    match list_keyboard_options(false) {
        Ok(groups) => result.success(Some(json!({ "groups": groups }))),
        Err(error) => result.error("xkb_registry_unavailable".to_owned(), error, None),
    }
}
