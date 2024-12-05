use crate::state::State;

use crate::flutter_engine::platform_channels::method_result::MethodResult;

use crate::flutter_engine::platform_channels::method_call::MethodCall;

use crate::backend::Backend;

pub fn get_monitor_layout<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    let monitors = data.space.outputs().cloned().collect::<Vec<_>>();
    data.flutter_engine_mut().monitor_layout_changed(monitors);
    result.success(None);
}
