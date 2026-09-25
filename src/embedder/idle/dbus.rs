use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use smithay::reexports::calloop::channel;
use tracing::warn;
use zbus::interface;
use zbus::message::Header;
use zbus::{Connection, Proxy};

use crate::settings::AutomaticPowerAction;

const SCREENSAVER_NAME: &str = "org.freedesktop.ScreenSaver";
const SCREENSAVER_PATH: &str = "/org/freedesktop/ScreenSaver";
const LOGIN1_NAME: &str = "org.freedesktop.login1";
const LOGIN1_PATH: &str = "/org/freedesktop/login1";
const LOGIN1_MANAGER: &str = "org.freedesktop.login1.Manager";

#[derive(Debug, Clone, Copy)]
pub enum IdleDbusEvent {
    Inhibited(bool),
    SimulateActivity,
}

#[derive(Default)]
struct Inhibitors {
    next_cookie: u32,
    owners: HashMap<u32, String>,
}

struct ScreenSaver {
    inhibitors: Arc<Mutex<Inhibitors>>,
    events: channel::Sender<IdleDbusEvent>,
}

#[interface(name = "org.freedesktop.ScreenSaver")]
impl ScreenSaver {
    async fn inhibit(
        &self,
        #[zbus(header)] header: Header<'_>,
        application_name: &str,
        reason: &str,
    ) -> u32 {
        let Some(owner) = header.sender().map(|sender| sender.to_string()) else {
            return 0;
        };

        let (cookie, inhibited) = {
            let mut inhibitors = self.inhibitors.lock().unwrap();
            inhibitors.next_cookie = inhibitors.next_cookie.wrapping_add(1).max(1);
            let cookie = inhibitors.next_cookie;
            inhibitors.owners.insert(cookie, owner.clone());
            (cookie, !inhibitors.owners.is_empty())
        };
        tracing::debug!(%application_name, %reason, %owner, cookie, "Screensaver inhibition requested");
        let _ = self.events.send(IdleDbusEvent::Inhibited(inhibited));
        cookie
    }

    #[zbus(name = "UnInhibit")]
    async fn un_inhibit(&self, #[zbus(header)] header: Header<'_>, cookie: u32) {
        let Some(owner) = header.sender().map(|sender| sender.to_string()) else {
            return;
        };
        let inhibited = {
            let mut inhibitors = self.inhibitors.lock().unwrap();
            if inhibitors
                .owners
                .get(&cookie)
                .is_some_and(|current| current == &owner)
            {
                inhibitors.owners.remove(&cookie);
            }
            !inhibitors.owners.is_empty()
        };
        tracing::debug!(%owner, cookie, inhibited, "Screensaver inhibition released");
        let _ = self.events.send(IdleDbusEvent::Inhibited(inhibited));
    }

    async fn simulate_user_activity(&self) {
        let _ = self.events.send(IdleDbusEvent::SimulateActivity);
    }
}

/// Run the screensaver D-Bus object on its own thread. Only inhibition state
/// crosses to the compositor loop; D-Bus callbacks never touch compositor data.
pub fn spawn(events: channel::Sender<IdleDbusEvent>) {
    std::thread::spawn(move || {
        if let Err(error) = zbus::block_on(serve(events)) {
            warn!(?error, "Screensaver D-Bus service did not start");
        }
    });
}

/// Queue logind power requests off the compositor thread.
pub fn spawn_power_worker() -> std::sync::mpsc::Sender<AutomaticPowerAction> {
    let (sender, requests) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        while let Ok(action) = requests.recv() {
            if action == AutomaticPowerAction::Disabled {
                continue;
            }
            if let Err(error) = zbus::block_on(request_logind_power_action(action)) {
                warn!(?action, ?error, "Automatic logind power action failed");
            }
        }
    });
    sender
}

async fn request_logind_power_action(action: AutomaticPowerAction) -> zbus::Result<()> {
    let connection = Connection::system().await?;
    let proxy = Proxy::new(&connection, LOGIN1_NAME, LOGIN1_PATH, LOGIN1_MANAGER).await?;
    let action = match action {
        AutomaticPowerAction::SuspendThenHibernate => {
            let capability = proxy
                .call::<_, _, String>("CanSuspendThenHibernate", &())
                .await;
            let capability = match capability {
                Ok(capability) => Some(capability),
                Err(error) => {
                    warn!(?error, "Could not query SuspendThenHibernate capability");
                    None
                }
            };
            select_suspend_then_hibernate_action(capability.as_deref())
        }
        action => action,
    };
    let method = match action {
        AutomaticPowerAction::Disabled => return Ok(()),
        AutomaticPowerAction::Suspend => "Suspend",
        AutomaticPowerAction::Hibernate => "Hibernate",
        AutomaticPowerAction::SuspendThenHibernate => "SuspendThenHibernate",
    };
    proxy.call_method(method, &(false,)).await?;
    Ok(())
}

fn select_suspend_then_hibernate_action(capability: Option<&str>) -> AutomaticPowerAction {
    if capability == Some("yes") {
        AutomaticPowerAction::SuspendThenHibernate
    } else {
        tracing::info!(
            ?capability,
            "SuspendThenHibernate is unavailable; falling back to Suspend"
        );
        AutomaticPowerAction::Suspend
    }
}

#[cfg(test)]
mod tests {
    use super::select_suspend_then_hibernate_action;
    use crate::settings::AutomaticPowerAction;

    #[test]
    fn suspend_then_hibernate_is_selected_only_when_logind_says_yes() {
        assert_eq!(
            select_suspend_then_hibernate_action(Some("yes")),
            AutomaticPowerAction::SuspendThenHibernate
        );
        for capability in [Some("no"), Some("challenge"), Some("na"), None] {
            assert_eq!(
                select_suspend_then_hibernate_action(capability),
                AutomaticPowerAction::Suspend
            );
        }
    }
}

async fn serve(events: channel::Sender<IdleDbusEvent>) -> zbus::Result<()> {
    let inhibitors = Arc::new(Mutex::new(Inhibitors::default()));
    let connection = zbus::connection::Builder::session()?
        .name(SCREENSAVER_NAME)?
        .serve_at(
            SCREENSAVER_PATH,
            ScreenSaver {
                inhibitors: inhibitors.clone(),
                events: events.clone(),
            },
        )?
        .build()
        .await?;

    let driver = zbus::fdo::DBusProxy::new(&connection).await?;
    let mut owner_changes = driver.receive_name_owner_changed().await?;
    while let Some(change) = owner_changes.next().await {
        let Ok(args) = change.args() else {
            continue;
        };
        if args.new_owner().is_some() {
            continue;
        }
        let owner = args.name().to_string();
        // D-Bus also emits changes for well-known names. Only release entries
        // keyed by the unique sender name that actually made the Inhibit call.
        if !owner.starts_with(':') {
            continue;
        }
        let inhibited = {
            let mut inhibitors = inhibitors.lock().unwrap();
            inhibitors.owners.retain(|_, current| current != &owner);
            !inhibitors.owners.is_empty()
        };
        let _ = events.send(IdleDbusEvent::Inhibited(inhibited));
    }
    drop(connection);
    Ok(())
}
