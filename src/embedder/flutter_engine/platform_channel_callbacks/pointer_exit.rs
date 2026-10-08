use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;
use crate::state::State;

pub fn pointer_exit<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    // See `pointer_focus`: while a game owns the input the compositor keeps the
    // focus it set on entry, so a shell-side exit must not clear it.
    if data.meta_window_state.meta_window_in_gaming_mode.is_some() {
        tracing::debug!("ignoring pointer exit while a game owns the input");
        result.success(None);
        return;
    }

    data.surface_id_under_cursor = None;

    data.pointer_focus = None;
    result.success(None);
}
