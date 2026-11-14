use serde_json::json;

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
    notify_keyboard_layout(data);
    result.success(None);
}

/// Tell the shell which of the keymap's layouts is active, for its status
/// bar: the layout's position in `keyboard.layout`, how many layouts the
/// keymap has, and the layout's xkb name (`English (US)`).
///
/// Sent whenever the active layout may have changed: after a switch, after
/// the keymap is recompiled from the settings (which resets it to the
/// first layout), and when the shell (re)starts.
pub fn notify_keyboard_layout<BackendData: Backend + 'static>(data: &mut State<BackendData>) {
    let keyboard = data.keyboard.clone();
    let (index, count, name) = keyboard.with_xkb_state(data, |context| {
        let xkb = context.xkb().lock().unwrap();
        let active = xkb.active_layout();
        (
            active.0,
            xkb.layouts().count(),
            xkb.layout_name(active).to_owned(),
        )
    });
    let Some(engine) = data.flutter_engine.as_mut() else {
        return;
    };
    engine.platform_method_channel.invoke_method(
        "keyboard_layout_changed",
        Some(Box::new(json!({
            "index": index,
            "count": count,
            "name": name,
        }))),
        None,
    );
}
