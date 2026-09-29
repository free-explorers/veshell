//! Loop-side handling of accepted notification calls.
//!
//! Accepted calls are forwarded to the Dart shell: `Notify` with the trusted
//! sender pid and its reply link parked until the shell answers with the id it
//! assigned, `CloseNotification` as a fire-and-forget teardown request. Calls
//! that arrive before the shell reports ready are queued and flushed from
//! `on_shell_ready`, so nothing is pushed to a shell that cannot receive it.

use serde_json::{json, Value as JsonValue};

use super::state::QueuedOutgoing;
use super::NotificationCall;
use crate::backend::Backend;
use crate::state::State;

pub fn handle_notification_call<BackendData: Backend + 'static>(
    data: &mut State<BackendData>,
    call: NotificationCall,
) {
    match call {
        NotificationCall::Notify {
            call_token,
            pid,
            sender,
            app_name,
            replaces_id,
            app_icon,
            summary,
            body,
            actions,
            hints,
            expire_timeout,
            reply,
        } => {
            data.notification_state
                .pending_notify
                .insert(call_token, (reply, sender));
            deliver(
                data,
                "notification_received",
                json!({
                    "callToken": call_token,
                    "notification": {
                        "pid": pid,
                        "appName": app_name,
                        "replacesId": replaces_id,
                        "appIcon": app_icon,
                        "summary": summary,
                        "body": body,
                        "actions": actions,
                        "hints": hints,
                        "expireTimeout": expire_timeout,
                    },
                }),
            );
        }
        NotificationCall::CloseNotification { id } => {
            deliver(data, "notification_close_requested", json!({ "id": id }));
        }
    }
}

/// Marks the shell ready to receive notification events and flushes the calls
/// accepted before it subscribed.
///
/// Driven by the shell's `notification_ready` request, which is sent once the
/// platform-event subscription exists.
pub fn mark_shell_ready<BackendData: Backend + 'static>(data: &mut State<BackendData>) {
    data.notification_state.shell_ready = true;
    let queued = std::mem::take(&mut data.notification_state.queued_outgoing);
    for outgoing in queued {
        data.flutter_engine_mut()
            .platform_method_channel
            .invoke_method(outgoing.method, Some(Box::new(outgoing.payload)), None);
    }
}

/// Pushes one shell event, or queues it until the shell is ready.
fn deliver<BackendData: Backend + 'static>(
    data: &mut State<BackendData>,
    method: &'static str,
    payload: JsonValue,
) {
    if data.notification_state.shell_ready {
        data.flutter_engine_mut()
            .platform_method_channel
            .invoke_method(method, Some(Box::new(payload)), None);
    } else {
        data.notification_state
            .queued_outgoing
            .push(QueuedOutgoing { method, payload });
    }
}
