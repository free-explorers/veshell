use crate::meta_window_state::meta_window::MetaWindowPatch;
use crate::state::State;

use crate::flutter_engine::platform_channels::method_result::MethodResult;

use crate::flutter_engine::platform_channels::method_call::MethodCall;

use crate::backend::Backend;

pub fn meta_window_patches<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let args = method_call.arguments().unwrap().clone();
    let payload: MetaWindowPatch = serde_json::from_value(args).unwrap();

    data.patch_meta_window(payload, false);
    result.success(None);
}
