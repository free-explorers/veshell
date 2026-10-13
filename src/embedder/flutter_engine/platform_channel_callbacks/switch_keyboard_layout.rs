use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;

use crate::state::State;

/// Advance the seat's keyboard to the next configured xkb layout.
///
/// The shell owns global hotkeys, so the layout toggle arrives as a platform
/// request rather than through an xkb `grp:*` option. The keymap already carries
/// every layout named by `keyboard.layout` (compiled once by
/// [`State::apply_veshell_settings`]); this only moves the active group and
/// broadcasts the resulting modifier change to the focused client.
pub fn switch_keyboard_layout<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    // Clone the handle first: `with_xkb_state` needs `&mut data` while
    // `data.keyboard` is borrowed, the same pattern the settings reload uses.
    let keyboard = data.keyboard.clone();
    keyboard.with_xkb_state(data, |mut xkb| xkb.cycle_next_layout());
    result.success(None);
}
