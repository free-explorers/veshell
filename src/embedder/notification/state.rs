//! Notification-owned state carried by the compositor [`State`]: the running
//! server, the shell-readiness gate that buffers calls until the shell can
//! receive them, and the loop-side reply table for `Notify` calls awaiting
//! their shell-assigned id.

use std::collections::HashMap;

use smithay::reexports::calloop::{self, LoopHandle};
use tracing::{info, warn};

use super::{spawn_notification_runtime, NotificationRuntime, NotifyReplyLink};
use crate::backend::Backend;
use crate::state::State;

/// An outgoing shell notification held until the shell reports ready.
pub struct QueuedOutgoing {
    pub method: &'static str,
    pub payload: serde_json::Value,
}

pub struct NotificationState {
    /// The running server, or `None` when this backend does not own the name
    /// (nested runs) or the session bus is unavailable.
    pub runtime: Option<NotificationRuntime>,
    /// Set once the shell has sent `shell_ready`. Until then accepted calls are
    /// queued instead of being pushed to a shell that cannot receive them.
    pub shell_ready: bool,
    /// Reply links of forwarded `Notify` calls, keyed by call token.
    /// Runtime-only: a shell reload drops them and the caller's reply fails.
    pub pending_notify: HashMap<u64, NotifyReplyLink>,
    /// Calls accepted before the shell was ready, flushed on `shell_ready`.
    pub queued_outgoing: Vec<QueuedOutgoing>,
}

impl NotificationState {
    pub fn new<BackendData: Backend + 'static>(
        loop_handle: &LoopHandle<'static, State<BackendData>>,
    ) -> Self {
        let runtime = if <BackendData as Backend>::RUNS_NOTIFICATION_SERVER {
            match spawn_notification_runtime() {
                Some(Ok((runtime, calls))) => {
                    loop_handle
                        .insert_source(calls, |event, _, state: &mut State<BackendData>| {
                            if let calloop::channel::Event::Msg(call) = event {
                                super::service::handle_notification_call(state, call);
                            }
                        })
                        .expect("Failed to init notification call bridge");
                    info!("Notification server listening on the session bus");
                    Some(runtime)
                }
                Some(Err(error)) => {
                    warn!(?error, "Notification server did not start");
                    None
                }
                None => {
                    warn!("No session bus is available for the notification server");
                    None
                }
            }
        } else {
            None
        };

        Self {
            runtime,
            shell_ready: false,
            pending_notify: HashMap::new(),
            queued_outgoing: Vec::new(),
        }
    }

    /// Completes the `Notify` call identified by `call_token` with the id the
    /// shell assigned. Unknown tokens (already answered, or from a previous
    /// shell) are ignored.
    pub fn complete_notify(&mut self, call_token: u64, id: u32) {
        if let Some(reply) = self.pending_notify.remove(&call_token) {
            reply.send(id);
        }
    }

    /// Emits `ActionInvoked(id, actionKey)` on the shell's behalf.
    pub fn emit_action_invoked(&self, id: u32, action_key: &str) {
        let Some(runtime) = &self.runtime else {
            return;
        };
        if let Err(error) = runtime.emit_action_invoked(id, action_key) {
            warn!(?error, id, action_key, "Failed to emit ActionInvoked");
        }
    }

    /// Emits `NotificationClosed(id, reason)` on the shell's behalf.
    pub fn emit_notification_closed(&self, id: u32, reason: u32) {
        let Some(runtime) = &self.runtime else {
            return;
        };
        if let Err(error) = runtime.emit_notification_closed(id, reason) {
            warn!(?error, id, reason, "Failed to emit NotificationClosed");
        }
    }
}
