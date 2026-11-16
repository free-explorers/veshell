//! Loop-side handling of watcher registration changes.
//!
//! Changes are forwarded to the Dart shell once it has subscribed; before
//! that they are only recorded, and `mark_shell_ready` delivers every item
//! registered so far.

use serde_json::{json, Value as JsonValue};

use super::{SystemTrayEvent, TrayItem};
use crate::backend::Backend;
use crate::state::State;

pub fn handle_system_tray_event<BackendData: Backend + 'static>(
    data: &mut State<BackendData>,
    event: SystemTrayEvent,
) {
    if !data.system_tray_state.apply(&event) || !data.system_tray_state.shell_ready {
        return;
    }
    match event {
        SystemTrayEvent::ItemRegistered(item) => {
            send(data, "system_tray_item_registered", item_payload(&item))
        }
        SystemTrayEvent::ItemUnregistered { id } => {
            send(data, "system_tray_item_unregistered", json!({ "id": id }))
        }
    }
}

/// Marks the shell ready to receive tray events and delivers every item
/// registered so far.
///
/// Driven by the shell's `system_tray_ready` request, sent once its
/// platform-event subscription exists. A reloaded shell asks again and gets
/// the whole set again.
pub fn mark_shell_ready<BackendData: Backend + 'static>(data: &mut State<BackendData>) {
    data.system_tray_state.shell_ready = true;
    let payloads: Vec<JsonValue> = data
        .system_tray_state
        .items
        .iter()
        .map(item_payload)
        .collect();
    for payload in payloads {
        send(data, "system_tray_item_registered", payload);
    }
}

fn item_payload(item: &TrayItem) -> JsonValue {
    json!({
        "id": item.id,
        "busName": item.bus_name,
        "objectPath": item.object_path,
        "pid": item.pid,
    })
}

fn send<BackendData: Backend + 'static>(
    data: &mut State<BackendData>,
    method: &'static str,
    payload: JsonValue,
) {
    data.flutter_engine_mut()
        .platform_method_channel
        .invoke_method(method, Some(Box::new(payload)), None);
}
