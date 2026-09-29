//! In-process Desktop Notifications server (`org.freedesktop.Notifications`).
//!
//! Rust owns the freedesktop D-Bus contract — the well-known name, the
//! interface and the signals — while the Dart shell owns state and interaction
//! (id assignment, routing, read/closed state, popups). This module is the
//! transport half of that split; see `docs/specifications/notification.md`.
//!
//! The shape mirrors the portal backend (`src/embedder/portal/`): the zbus
//! interface never touches compositor state, it pushes every accepted call
//! onto a calloop channel and completes `Notify` through a token/reply link
//! once the shell answers with the id it assigned.
//!
//! Calls accepted before the shell subscribes are queued and flushed on the
//! shell's `notification_ready` request, so nothing is pushed to a shell that
//! cannot receive it.

use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};

use serde_json::json;
use smithay::reexports::calloop;
use zbus::connection::Builder as ConnectionBuilder;
use zbus::message::Header;
use zbus::zvariant::{OwnedValue, Value as ZValue};
use zbus::{interface, Connection, Proxy};

pub mod service;
pub mod state;

#[cfg(test)]
mod harness;

pub use state::NotificationState;

/// Well-known session-bus name served by the compositor.
pub const NOTIFICATION_NAME: &str = "org.freedesktop.Notifications";
/// Object path of the notification server object.
pub const NOTIFICATION_PATH: &str = "/org/freedesktop/Notifications";
/// Interface served on [`NOTIFICATION_PATH`].
pub const NOTIFICATION_INTERFACE: &str = "org.freedesktop.Notifications";

/// Capabilities advertised by `GetCapabilities`. `body`, `actions` and
/// `persistence` are honored: bodies and action buttons are rendered, the
/// `resident` hint is honored, and `CloseNotification` is implemented.
pub const CAPABILITIES: [&str; 3] = ["body", "actions", "persistence"];

/// A validated notification call from the bus, pushed to the compositor loop.
pub enum NotificationCall {
    /// `Notify(...)`: the trusted sender pid is resolved before forwarding.
    ///
    /// The shell owns id assignment, so the loop answers through `reply` once
    /// it has forwarded the payload and received the id back.
    Notify {
        call_token: u64,
        pid: Option<i32>,
        /// The sender's unique bus name, so signals meant only for it (the
        /// activation token) can be unicast.
        sender: Option<String>,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        /// The DBus `a{sv}` hints, already marshalled to the Dart
        /// `NotificationHints` field names (the shell owns no DBus types).
        hints: serde_json::Value,
        expire_timeout: i32,
        reply: NotifyReplyLink,
    },
    /// `CloseNotification(id)`: tears down the live popup. The shell decides
    /// whether a `NotificationClosed(reason 3)` signal follows.
    CloseNotification { id: u32 },
}

pub type CallReceiver = calloop::channel::Channel<NotificationCall>;

/// Loop-side handle for answering one pending `Notify` call.
///
/// Senders must not block: this is an unbounded async channel, and the
/// interface awaits it on the zbus executor until the loop answers with the
/// shell-assigned id.
#[derive(Clone, Debug)]
pub struct NotifyReplyLink {
    tx: async_channel::Sender<u32>,
}

impl NotifyReplyLink {
    pub fn send(self, id: u32) {
        let _ = self.tx.send_blocking(id);
    }
}

pub(crate) fn make_notify_reply() -> (NotifyReplyLink, async_channel::Receiver<u32>) {
    let (tx, rx) = async_channel::unbounded();
    (NotifyReplyLink { tx }, rx)
}

fn stopped_error() -> zbus::fdo::Error {
    zbus::fdo::Error::Failed("notification service stopped".into())
}

/// The served `org.freedesktop.Notifications` object.
struct NotificationsBackend {
    calls: calloop::channel::Sender<NotificationCall>,
    /// Monotonic correlation token for `Notify` calls forwarded to the shell.
    next_token: AtomicU64,
}

impl NotificationsBackend {
    fn new(calls: calloop::channel::Sender<NotificationCall>) -> Self {
        Self {
            calls,
            next_token: AtomicU64::new(1),
        }
    }
}

#[interface(name = "org.freedesktop.Notifications")]
impl NotificationsBackend {
    /// Static protocol metadata: answered without a shell round trip.
    async fn get_capabilities(&self) -> Vec<String> {
        CAPABILITIES
            .iter()
            .map(|capability| capability.to_string())
            .collect()
    }

    /// Static protocol metadata: answered without a shell round trip.
    async fn get_server_information(&self) -> (String, String, String, String) {
        (
            "VeshellNotificationServer".to_string(),
            "Veshell".to_string(),
            "1.0".to_string(),
            "1.2".to_string(),
        )
    }

    /// `Notify(...) -> u32`: forwards the payload with the trusted sender pid
    /// and waits for the shell-assigned id before completing the D-Bus reply.
    async fn notify(
        &self,
        #[zbus(header)] header: Header<'_>,
        #[zbus(connection)] connection: &Connection,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        hints: HashMap<String, OwnedValue>,
        expire_timeout: i32,
    ) -> zbus::fdo::Result<u32> {
        let pid =
            resolve_sender_pid(connection, header.sender().map(|sender| sender.to_string())).await;
        let sender = header.sender().map(|sender| sender.to_string());
        let (reply, pending) = make_notify_reply();
        let call_token = self.next_token.fetch_add(1, Ordering::SeqCst);
        self.calls
            .send(NotificationCall::Notify {
                call_token,
                pid,
                sender,
                app_name,
                replaces_id,
                app_icon,
                summary,
                body,
                actions,
                hints: hints_to_json(&hints),
                expire_timeout,
                reply,
            })
            .map_err(|_| stopped_error())?;
        pending.recv().await.map_err(|_| stopped_error())
    }

    /// `CloseNotification(u)`: fire-and-forget; the shell decides the signal.
    #[zbus(name = "CloseNotification")]
    async fn close_notification(&self, id: u32) -> zbus::fdo::Result<()> {
        self.calls
            .send(NotificationCall::CloseNotification { id })
            .map_err(|_| stopped_error())?;
        Ok(())
    }
}

/// Resolves the trusted pid behind a sender's unique name.
///
/// The `pid` a client passes in `Notify` is untrusted; the bus driver is the
/// authority. Best effort: an unresolvable sender yields `None` and the shell
/// falls back to the `desktop-entry` hint.
async fn resolve_sender_pid(connection: &Connection, sender: Option<String>) -> Option<i32> {
    let sender = sender?;
    let proxy = Proxy::new(
        connection,
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
    )
    .await
    .ok()?;
    let pid: u32 = proxy
        .call("GetConnectionUnixProcessID", &(sender.as_str(),))
        .await
        .ok()?;
    Some(pid as i32)
}

/// Marshals the DBus `a{sv}` hints to the Dart `NotificationHints` field
/// names, carrying only the hints the shell consumes.
///
/// The shell owns no DBus value types: the protocol-side mapping (including
/// the `image-data`/`icon-data` array shape) stays in Rust. Structurally
/// unsupported or unknown hints are dropped, leaving the shell field `null`,
/// which is what the previous Dart parser effectively produced for them.
fn hints_to_json(hints: &HashMap<String, OwnedValue>) -> serde_json::Value {
    let mut out = serde_json::Map::new();
    insert_string(&mut out, hints, "category", "category");
    insert_string(&mut out, hints, "desktop-entry", "desktopEntry");
    insert_string(&mut out, hints, "image-path", "imagePath");
    insert_string(&mut out, hints, "sound-file", "soundFile");
    insert_string(&mut out, hints, "sound-name", "soundName");
    insert_bool(&mut out, hints, "action-icons", "actionIcons");
    insert_bool(&mut out, hints, "resident", "resident");
    insert_bool(&mut out, hints, "suppress-sound", "suppressSound");
    insert_bool(&mut out, hints, "transient", "transient");
    insert_int(&mut out, hints, "x", "x");
    insert_int(&mut out, hints, "y", "y");
    insert_int(&mut out, hints, "urgency", "urgency");
    serde_json::Value::Object(out)
}

fn raw_hint<'a>(hints: &'a HashMap<String, OwnedValue>, key: &str) -> Option<&'a ZValue<'static>> {
    hints.get(key).map(|value| &**value)
}

fn insert_string(
    out: &mut serde_json::Map<String, serde_json::Value>,
    hints: &HashMap<String, OwnedValue>,
    key: &str,
    field: &str,
) {
    match raw_hint(hints, key) {
        Some(ZValue::Str(text)) => {
            out.insert(field.to_string(), json!(text.as_str()));
        }
        Some(ZValue::ObjectPath(path)) => {
            out.insert(field.to_string(), json!(path.as_str()));
        }
        _ => {}
    }
}

fn insert_bool(
    out: &mut serde_json::Map<String, serde_json::Value>,
    hints: &HashMap<String, OwnedValue>,
    key: &str,
    field: &str,
) {
    if let Some(ZValue::Bool(flag)) = raw_hint(hints, key) {
        out.insert(field.to_string(), json!(*flag));
    }
}

fn insert_int(
    out: &mut serde_json::Map<String, serde_json::Value>,
    hints: &HashMap<String, OwnedValue>,
    key: &str,
    field: &str,
) {
    if let Some(number) = raw_hint(hints, key).and_then(int_value) {
        out.insert(field.to_string(), json!(number));
    }
}

/// Widens any integer DBus value to `i64`; the shell model stores ints.
fn int_value(value: &ZValue<'_>) -> Option<i64> {
    match value {
        ZValue::U8(value) => Some(*value as i64),
        ZValue::I16(value) => Some(*value as i64),
        ZValue::U16(value) => Some(*value as i64),
        ZValue::I32(value) => Some(*value as i64),
        ZValue::U32(value) => Some(*value as i64),
        ZValue::I64(value) => Some(*value),
        ZValue::U64(value) => i64::try_from(*value).ok(),
        _ => None,
    }
}

/// Keeps the served connection alive for the lifetime of the session.
pub struct NotificationRuntime {
    _connection: Connection,
}

impl NotificationRuntime {
    /// Emits `ActionInvoked(id, actionKey)` on the shell's behalf.
    pub fn emit_action_invoked(&self, id: u32, action_key: &str) -> zbus::Result<()> {
        zbus::block_on(self._connection.emit_signal(
            Option::<zbus::names::BusName>::None,
            NOTIFICATION_PATH,
            NOTIFICATION_INTERFACE,
            "ActionInvoked",
            &(id, action_key),
        ))
    }

    /// Emits `NotificationClosed(id, reason)` on the shell's behalf.
    pub fn emit_notification_closed(&self, id: u32, reason: u32) -> zbus::Result<()> {
        zbus::block_on(self._connection.emit_signal(
            Option::<zbus::names::BusName>::None,
            NOTIFICATION_PATH,
            NOTIFICATION_INTERFACE,
            "NotificationClosed",
            &(id, reason),
        ))
    }

    /// Emits `ActivationToken(id, token)` on the shell's behalf.
    ///
    /// Carries a compositor-minted token the sender can hand to
    /// `xdg_activation_v1` to activate its own toplevel. The spec allows it
    /// before `ActionInvoked`, which is how a client opened from a notification
    /// action gets a focus grant. Unicast to `destination` (the sender's unique
    /// name): the token is a focus grant and must not leak to other clients.
    pub fn emit_activation_token(
        &self,
        id: u32,
        token: &str,
        destination: Option<&str>,
    ) -> zbus::Result<()> {
        zbus::block_on(self._connection.emit_signal(
            destination,
            NOTIFICATION_PATH,
            NOTIFICATION_INTERFACE,
            "ActivationToken",
            &(id, token),
        ))
    }
}

/// Starts the server on the session bus. Returns `None` when there is no
/// usable session bus; the caller decides what that means for this run.
pub fn spawn_notification_runtime() -> Option<zbus::Result<(NotificationRuntime, CallReceiver)>> {
    Some(zbus::block_on(start_notification_server()))
}

async fn start_notification_server() -> zbus::Result<(NotificationRuntime, CallReceiver)> {
    let (calls, receiver) = calloop::channel::channel::<NotificationCall>();
    let connection = ConnectionBuilder::session()?
        .name(NOTIFICATION_NAME)?
        .serve_at(NOTIFICATION_PATH, NotificationsBackend::new(calls))?
        .build()
        .await?;
    Ok((
        NotificationRuntime {
            _connection: connection,
        },
        receiver,
    ))
}

/// Builds the server on an explicit bus address. Test-only: production runs go
/// through [`start_notification_server`] and the session bus.
#[cfg(test)]
async fn build_notification_connection(address: &str) -> zbus::Result<(Connection, CallReceiver)> {
    let (calls, receiver) = calloop::channel::channel::<NotificationCall>();
    let connection = ConnectionBuilder::address(address)?
        .name(NOTIFICATION_NAME)?
        .serve_at(NOTIFICATION_PATH, NotificationsBackend::new(calls))?
        .build()
        .await?;
    Ok((connection, receiver))
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use zbus::zvariant::{OwnedValue, Str};

    use super::hints_to_json;

    #[test]
    fn hints_are_marshalled_to_shell_field_names() {
        let mut hints = HashMap::new();
        hints.insert(
            "desktop-entry".to_string(),
            OwnedValue::from(Str::from("org.example.App")),
        );
        hints.insert("resident".to_string(), OwnedValue::from(true));
        hints.insert("x".to_string(), OwnedValue::from(12i32));
        hints.insert("urgency".to_string(), OwnedValue::from(1u8));
        // A structurally unsupported value: dropped, not mis-typed.
        hints.insert(
            "image-data".to_string(),
            OwnedValue::from(HashMap::<String, i32>::new()),
        );

        let json = hints_to_json(&hints);
        assert_eq!(json["desktopEntry"].as_str(), Some("org.example.App"));
        assert_eq!(json["resident"].as_bool(), Some(true));
        assert_eq!(json["x"].as_i64(), Some(12));
        assert_eq!(json["urgency"].as_i64(), Some(1));
        assert!(json.get("imageData").is_none());
    }
}
