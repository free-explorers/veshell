//! In-process StatusNotifierItem watcher (`org.kde.StatusNotifierWatcher`).
//!
//! Applications publish their tray icon as a `org.kde.StatusNotifierItem`
//! object and register it with the watcher; hosts ask the watcher which items
//! exist. Rust owns the watcher's well-known name, interface and signals, while
//! the Dart shell is the host: it reads every item (icon, tooltip, menu) as a
//! client of the session bus. See `docs/specifications/system_tray.md`.
//!
//! The watcher runs on its own thread like the screensaver service
//! (`src/embedder/idle/dbus.rs`): D-Bus callbacks never touch compositor data,
//! only registration changes cross to the compositor loop over a calloop
//! channel.

use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use smithay::reexports::calloop;
use tracing::warn;
use zbus::connection::Builder as ConnectionBuilder;
use zbus::message::Header;
use zbus::names::BusName;
use zbus::object_server::SignalEmitter;
use zbus::zvariant::ObjectPath;
use zbus::{interface, Connection};

pub mod service;
pub mod state;

#[cfg(test)]
mod harness;

pub use state::SystemTrayState;

/// Well-known session-bus name served by the compositor.
pub const WATCHER_NAME: &str = "org.kde.StatusNotifierWatcher";
/// Object path of the watcher object.
pub const WATCHER_PATH: &str = "/StatusNotifierWatcher";
/// Interface served on [`WATCHER_PATH`] (the `#[interface]` attribute needs
/// the literal; clients in the tests use this).
#[cfg(test)]
pub const WATCHER_INTERFACE: &str = "org.kde.StatusNotifierWatcher";
/// Object path of an item registered by bus name only.
pub const DEFAULT_ITEM_PATH: &str = "/StatusNotifierItem";
/// `ProtocolVersion` reported by the watcher, as every known watcher does.
pub const PROTOCOL_VERSION: i32 = 0;

/// A registered item, as the shell needs it to talk to the application.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TrayItem {
    /// The watcher's item id: the bus name followed by the object path, which
    /// is what `RegisteredStatusNotifierItems` and the signals carry.
    pub id: String,
    /// The bus name the item was registered under: a well-known name, or the
    /// sender's unique name when it registered an object path.
    pub bus_name: String,
    pub object_path: String,
    /// The process behind the bus name, resolved by the bus driver, so the
    /// shell can tie the item to the application's windows.
    pub pid: Option<i32>,
}

/// A registration change, pushed to the compositor loop.
#[derive(Debug, PartialEq, Eq)]
pub enum SystemTrayEvent {
    ItemRegistered(TrayItem),
    ItemUnregistered { id: String },
}

pub type EventReceiver = calloop::channel::Channel<SystemTrayEvent>;

/// The items in registration order, shared by the interface and the name
/// owner tracker.
type Registry = Arc<Mutex<Vec<TrayItem>>>;

/// Resolves the bus name and object path behind a `RegisterStatusNotifierItem`
/// argument.
///
/// The specification passes a bus name, but implementations also pass an
/// object path (libappindicator, Ayatana: the item lives on the sender's own
/// connection) or a bus name immediately followed by a path. `None` when the
/// argument names neither a valid bus name nor a valid path.
pub fn resolve_item_address(service: &str, sender: Option<&str>) -> Option<(String, String)> {
    let (bus_name, object_path) = if service.starts_with('/') {
        (sender?.to_string(), service.to_string())
    } else if let Some(index) = service.find('/') {
        (service[..index].to_string(), service[index..].to_string())
    } else {
        (service.to_string(), DEFAULT_ITEM_PATH.to_string())
    };
    BusName::try_from(bus_name.as_str()).ok()?;
    ObjectPath::try_from(object_path.as_str()).ok()?;
    Some((bus_name, object_path))
}

/// The served `org.kde.StatusNotifierWatcher` object.
struct Watcher {
    registry: Registry,
    events: calloop::channel::Sender<SystemTrayEvent>,
}

#[interface(name = "org.kde.StatusNotifierWatcher")]
impl Watcher {
    /// Registers an item, by bus name or by object path on the sender's
    /// connection. Registering the same item again is accepted and ignored.
    async fn register_status_notifier_item(
        &self,
        #[zbus(header)] header: Header<'_>,
        #[zbus(connection)] connection: &Connection,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        service: String,
    ) -> zbus::fdo::Result<()> {
        let sender = header.sender().map(|sender| sender.to_string());
        let (bus_name, object_path) = resolve_item_address(&service, sender.as_deref())
            .ok_or_else(|| {
                zbus::fdo::Error::InvalidArgs(format!("not an item address: {service}"))
            })?;
        let id = format!("{bus_name}{object_path}");
        if self.contains(&id) {
            return Ok(());
        }

        let driver = zbus::fdo::DBusProxy::new(connection).await?;
        let owned = BusName::try_from(bus_name.as_str())
            .map_err(|error| zbus::fdo::Error::InvalidArgs(error.to_string()))?;
        let pid = driver
            .get_connection_unix_process_id(owned.clone())
            .await
            .ok()
            .map(|pid| pid as i32);
        let item = TrayItem {
            id: id.clone(),
            bus_name: bus_name.clone(),
            object_path,
            pid,
        };
        {
            let mut registry = self.registry.lock().unwrap();
            if registry.iter().any(|known| known.id == id) {
                return Ok(());
            }
            registry.push(item.clone());
        }
        // The owner may have gone while the pid was resolved, in which case the
        // tracker's `NameOwnerChanged` already passed: check once more so a
        // vanished item is never kept.
        if !driver.name_has_owner(owned).await.unwrap_or(false) {
            self.registry.lock().unwrap().retain(|known| known.id != id);
            return Ok(());
        }

        let _ = self.events.send(SystemTrayEvent::ItemRegistered(item));
        Self::status_notifier_item_registered(&emitter, &id).await?;
        self.registered_status_notifier_items_changed(&emitter)
            .await?;
        Ok(())
    }

    /// Veshell is the session's host; other hosts are accepted so they keep
    /// working, but the watcher always reports a host.
    async fn register_status_notifier_host(&self, _service: String) {}

    #[zbus(property)]
    async fn registered_status_notifier_items(&self) -> Vec<String> {
        self.registry
            .lock()
            .unwrap()
            .iter()
            .map(|item| item.id.clone())
            .collect()
    }

    /// Always true: the shell is the host. Reporting it from the start keeps
    /// applications that launch with the session from falling back to an
    /// X11 tray before the shell has subscribed (the compositor holds their
    /// registration until then).
    #[zbus(property)]
    async fn is_status_notifier_host_registered(&self) -> bool {
        true
    }

    #[zbus(property)]
    async fn protocol_version(&self) -> i32 {
        PROTOCOL_VERSION
    }

    #[zbus(signal)]
    async fn status_notifier_item_registered(
        emitter: &SignalEmitter<'_>,
        service: &str,
    ) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn status_notifier_item_unregistered(
        emitter: &SignalEmitter<'_>,
        service: &str,
    ) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn status_notifier_host_registered(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn status_notifier_host_unregistered(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;
}

impl Watcher {
    fn contains(&self, id: &str) -> bool {
        self.registry
            .lock()
            .unwrap()
            .iter()
            .any(|item| item.id == id)
    }
}

/// Builds the watcher connection. `address` is a private bus in tests, the
/// session bus otherwise.
async fn build_connection(
    address: Option<&str>,
    registry: Registry,
    events: calloop::channel::Sender<SystemTrayEvent>,
) -> zbus::Result<Connection> {
    let builder = match address {
        Some(address) => ConnectionBuilder::address(address)?,
        None => ConnectionBuilder::session()?,
    };
    builder
        .name(WATCHER_NAME)?
        // The conventional host name, for applications that look for one.
        .name(format!("org.kde.StatusNotifierHost-{}", std::process::id()))?
        .serve_at(WATCHER_PATH, Watcher { registry, events })?
        .build()
        .await
}

/// Serves the watcher until the connection ends, unregistering every item
/// whose bus name loses its owner. `started` reports whether the name was
/// taken.
async fn serve(
    address: Option<String>,
    events: calloop::channel::Sender<SystemTrayEvent>,
    started: std::sync::mpsc::Sender<zbus::Result<()>>,
) {
    let registry: Registry = Arc::default();
    let connection =
        match build_connection(address.as_deref(), registry.clone(), events.clone()).await {
            Ok(connection) => connection,
            Err(error) => {
                let _ = started.send(Err(error));
                return;
            }
        };
    let owner_changes = match zbus::fdo::DBusProxy::new(&connection).await {
        Ok(driver) => driver.receive_name_owner_changed().await,
        Err(error) => Err(error.into()),
    };
    let mut owner_changes = match owner_changes {
        Ok(stream) => stream,
        Err(error) => {
            let _ = started.send(Err(error));
            return;
        }
    };
    let _ = started.send(Ok(()));

    while let Some(change) = owner_changes.next().await {
        let Ok(args) = change.args() else {
            continue;
        };
        if args.new_owner().is_some() {
            continue;
        }
        let name = args.name().to_string();
        // An item hidden by its application releases its well-known name while
        // the application stays connected, so every name counts, not only the
        // unique ones.
        let removed: Vec<String> = {
            let mut registry = registry.lock().unwrap();
            let removed = registry
                .iter()
                .filter(|item| item.bus_name == name)
                .map(|item| item.id.clone())
                .collect();
            registry.retain(|item| item.bus_name != name);
            removed
        };
        if removed.is_empty() {
            continue;
        }
        let Ok(watcher) = connection
            .object_server()
            .interface::<_, Watcher>(WATCHER_PATH)
            .await
        else {
            continue;
        };
        for id in removed {
            let _ = events.send(SystemTrayEvent::ItemUnregistered { id: id.clone() });
            if let Err(error) =
                Watcher::status_notifier_item_unregistered(watcher.signal_emitter(), &id).await
            {
                warn!(?error, id, "Failed to emit StatusNotifierItemUnregistered");
            }
        }
        let _ = watcher
            .get()
            .await
            .registered_status_notifier_items_changed(watcher.signal_emitter())
            .await;
    }
}

/// Starts the watcher on its own thread, on the session bus or on `address`.
/// Returns once the name is taken, with the receiver of registration changes.
pub fn spawn_watcher(address: Option<String>) -> zbus::Result<EventReceiver> {
    let (events, receiver) = calloop::channel::channel::<SystemTrayEvent>();
    let (started, start_result) = std::sync::mpsc::channel();
    std::thread::Builder::new()
        .name("system-tray-watcher".into())
        .spawn(move || zbus::block_on(serve(address, events, started)))
        .map_err(|error| zbus::Error::Failure(error.to_string()))?;
    start_result
        .recv()
        .map_err(|_| zbus::Error::Failure("system tray watcher thread ended".into()))??;
    Ok(receiver)
}

#[cfg(test)]
mod tests {
    use super::{resolve_item_address, DEFAULT_ITEM_PATH};

    #[test]
    fn a_bus_name_registers_the_default_path() {
        assert_eq!(
            resolve_item_address("org.kde.StatusNotifierItem-42-1", Some(":1.7")),
            Some((
                "org.kde.StatusNotifierItem-42-1".to_string(),
                DEFAULT_ITEM_PATH.to_string()
            ))
        );
    }

    #[test]
    fn an_object_path_lives_on_the_sender() {
        assert_eq!(
            resolve_item_address("/org/ayatana/NotificationItem/app", Some(":1.7")),
            Some((
                ":1.7".to_string(),
                "/org/ayatana/NotificationItem/app".to_string()
            ))
        );
        assert_eq!(resolve_item_address("/StatusNotifierItem", None), None);
    }

    #[test]
    fn a_bus_name_may_carry_its_path() {
        assert_eq!(
            resolve_item_address(":1.7/org/example/Item", None),
            Some((":1.7".to_string(), "/org/example/Item".to_string()))
        );
    }

    #[test]
    fn invalid_addresses_are_refused() {
        assert_eq!(resolve_item_address("", Some(":1.7")), None);
        assert_eq!(resolve_item_address("not a name", Some(":1.7")), None);
        assert_eq!(resolve_item_address(":1.7/bad//path", None), None);
    }
}
