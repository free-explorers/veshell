use serde_json::Value;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

/// The shell has subscribed to system tray events: mark it ready and deliver
/// every item registered so far.
pub fn system_tray_ready<BackendData: Backend + 'static>(
    _method_call: MethodCall<Value>,
    mut result: Box<dyn MethodResult<Value>>,
    data: &mut State<BackendData>,
) {
    crate::system_tray::service::mark_shell_ready(data);
    result.success(None);
}
