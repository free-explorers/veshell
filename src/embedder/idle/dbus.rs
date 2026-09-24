use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use smithay::reexports::calloop::channel;
use tracing::warn;
use zbus::interface;
use zbus::message::Header;

const SCREENSAVER_NAME: &str = "org.freedesktop.ScreenSaver";
const SCREENSAVER_PATH: &str = "/org/freedesktop/ScreenSaver";

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
