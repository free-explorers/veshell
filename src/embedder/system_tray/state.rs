//! System-tray state carried by the compositor [`State`]: the registered items
//! as the loop last heard of them, and the shell-readiness gate.
//!
//! The loop keeps its own copy of the item list so it can hand the whole set
//! to a shell that subscribes late (or reloads) without asking the watcher
//! thread.

use std::time::{Duration, Instant};

use smithay::reexports::calloop::{self, LoopHandle};
use tracing::{info, warn};

use super::{spawn_watcher, SystemTrayEvent, TrayItem};
use crate::backend::Backend;
use crate::state::State;

pub struct SystemTrayState {
    /// Whether the watcher owns its name in this run.
    pub running: bool,
    /// Set once the shell has sent `system_tray_ready`. Until then changes
    /// are only recorded, and the ready request delivers the whole set.
    pub shell_ready: bool,
    /// The registered items, in registration order.
    pub items: Vec<TrayItem>,
    /// Processes whose tray item the user just activated, and when. See
    /// [`SystemTrayState::take_activation_grant`].
    activation_grants: Vec<(i32, Instant)>,
}

/// How long after a click on its tray item an application's own activation
/// request still counts as the user's: it answers `Activate` at once.
const ACTIVATION_GRANT_TTL: Duration = Duration::from_secs(3);

impl SystemTrayState {
    pub fn new<BackendData: Backend + 'static>(
        loop_handle: &LoopHandle<'static, State<BackendData>>,
    ) -> Self {
        // The probe's isolated instance runs nested on a private session bus
        // of its own, where owning the name contends with nobody.
        let probe_isolated = std::env::var_os("VESHELL_PROBE_ISOLATED").is_some_and(|v| v == "1");
        let running = if <BackendData as Backend>::RUNS_SYSTEM_TRAY_WATCHER || probe_isolated {
            match spawn_watcher(None) {
                Ok(events) => {
                    loop_handle
                        .insert_source(events, |event, _, state: &mut State<BackendData>| {
                            if let calloop::channel::Event::Msg(event) = event {
                                super::service::handle_system_tray_event(state, event);
                            }
                        })
                        .expect("Failed to init system tray event bridge");
                    info!("System tray watcher listening on the session bus");
                    true
                }
                Err(error) => {
                    warn!(?error, "System tray watcher did not start");
                    false
                }
            }
        } else {
            false
        };

        Self {
            running,
            shell_ready: false,
            items: Vec::new(),
            activation_grants: Vec::new(),
        }
    }

    /// The process behind the item `id`, when known.
    pub fn item_pid(&self, id: &str) -> Option<i32> {
        self.items
            .iter()
            .find(|item| item.id == id)
            .and_then(|item| item.pid)
    }

    /// Records that the user activated the tray item of process `pid`.
    pub fn grant_activation(&mut self, pid: i32) {
        self.activation_grants
            .retain(|(granted, at)| *granted != pid && at.elapsed() < ACTIVATION_GRANT_TTL);
        self.activation_grants.push((pid, Instant::now()));
    }

    /// Consumes the grant of process `pid`: whether the user activated its tray
    /// item moments ago, so the window it activates now is the one the user
    /// asked for. Single use.
    pub fn take_activation_grant(&mut self, pid: i32) -> bool {
        self.activation_grants
            .retain(|(_, at)| at.elapsed() < ACTIVATION_GRANT_TTL);
        let before = self.activation_grants.len();
        self.activation_grants
            .retain(|(granted, _)| *granted != pid);
        self.activation_grants.len() != before
    }

    /// Applies a registration change to the item list. Returns whether it
    /// changed anything.
    pub fn apply(&mut self, event: &SystemTrayEvent) -> bool {
        match event {
            SystemTrayEvent::ItemRegistered(item) => {
                if self.items.iter().any(|known| known.id == item.id) {
                    return false;
                }
                self.items.push(item.clone());
                true
            }
            SystemTrayEvent::ItemUnregistered { id } => {
                let before = self.items.len();
                self.items.retain(|item| &item.id != id);
                self.items.len() != before
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::SystemTrayState;

    fn state() -> SystemTrayState {
        SystemTrayState {
            running: false,
            shell_ready: false,
            items: Vec::new(),
            activation_grants: Vec::new(),
        }
    }

    #[test]
    fn an_activation_grant_is_for_its_process_and_used_once() {
        let mut state = state();
        state.grant_activation(42);
        assert!(!state.take_activation_grant(7));
        assert!(state.take_activation_grant(42));
        // A second request from the same click is not trusted again.
        assert!(!state.take_activation_grant(42));
    }

    #[test]
    fn a_new_click_renews_the_grant_without_stacking() {
        let mut state = state();
        state.grant_activation(42);
        state.grant_activation(42);
        assert!(state.take_activation_grant(42));
        assert!(!state.take_activation_grant(42));
    }
}
