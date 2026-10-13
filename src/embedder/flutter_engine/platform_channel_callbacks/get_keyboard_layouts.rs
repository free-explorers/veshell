use serde_json::json;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::keyboard::xkb_registry::list_keyboard_layouts;
use crate::state::State;

#[derive(Debug, Default, serde::Deserialize)]
#[serde(rename_all = "camelCase", default)]
struct GetKeyboardLayoutsPayload {
    /// Also load the rarely used "exotic" rulesets (GNOME's "show all
    /// sources"). Defaults to off so the picker stays short.
    include_exotic: bool,
}

/// Return the layout catalogue the compositor can compile, read from
/// libxkbregistry. The shell backs its keyboard-layout picker with this.
pub fn get_keyboard_layouts<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    _data: &mut State<BackendData>,
) {
    let include_exotic = method_call
        .arguments()
        .and_then(|value| serde_json::from_value::<GetKeyboardLayoutsPayload>(value.clone()).ok())
        .unwrap_or_default()
        .include_exotic;

    match list_keyboard_layouts(include_exotic) {
        Ok(layouts) => result.success(Some(json!({ "layouts": layouts }))),
        Err(error) => result.error("xkb_registry_unavailable".to_owned(), error, None),
    }
}
