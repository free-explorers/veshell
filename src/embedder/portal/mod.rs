//! In-process xdg-desktop-portal backend for Veshell.
//!
//! This slice (M2.0) covers the D-Bus pieces that do not depend on the
//! compositor state: the ScreenCast/Request backend contracts, response-code
//! semantics, request validation, frontend authorization, and the bridge
//! that pushes incoming calls onto a calloop channel so replies are
//! completed on the event loop thread. The State wiring lands in the
//! following milestone.

//! following milestone.

// M2.0 ships the contract skeletons ahead of their consumers: the M2.1
// state machine starts using them without changing the shape.
#![allow(dead_code)]

use std::collections::HashMap;

use smithay::reexports::calloop;
use zbus::connection::Builder as ConnectionBuilder;
pub mod service;

#[cfg(test)]
pub static HARNESS_TEST_COUNTER: std::sync::atomic::AtomicU64 =
    std::sync::atomic::AtomicU64::new(0);

#[cfg(test)]
mod harness;
use futures_util::StreamExt;
use zbus::message::Header;
use zbus::zvariant::{ObjectPath, OwnedObjectPath, OwnedValue};
use zbus::{interface, Connection};

/// Well-known backend name owned by the Veshell compositor process.
pub const BACKEND_NAME: &str = "org.freedesktop.impl.portal.desktop.veshell";
/// Well-known name of the xdg-desktop-portal frontend: the only authorized
/// caller identity.
pub const FRONTEND_NAME: &str = "org.freedesktop.portal.Desktop";
/// Backend object path shared by all backend interfaces.
pub const DESKTOP_PATH: &str = "/org/freedesktop/portal/desktop";

pub const SCREENCAST_INTERFACE: &str = "org.freedesktop.impl.portal.ScreenCast";
pub const REQUEST_INTERFACE: &str = "org.freedesktop.impl.portal.Request";
pub const SESSION_INTERFACE: &str = "org.freedesktop.impl.portal.Session";

/// ScreenCast backend contract version advertised by Veshell.
pub const SCREENCAST_BACKEND_VERSION: u32 = 4;
/// Request/Session object version of the contracts we implement.
pub const REQUEST_SESSION_VERSION: u32 = 2;

/// Backend response code: completed.
pub const RESPONSE_OK: u32 = 0;
/// Backend response code: cancelled by the user.
pub const RESPONSE_CANCELLED: u32 = 1;
/// Backend response code: other failure.
pub const RESPONSE_FAILED: u32 = 2;

bitflags::bitflags! {
    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    pub struct SourceTypes: u32 {
        const MONITOR = 1;
        const WINDOW = 2;
        const VIRTUAL = 4;
    }
}

bitflags::bitflags! {
    #[derive(Debug, Clone, Copy, PartialEq, Eq)]
    pub struct CursorModes: u32 {
        const HIDDEN = 1;
        const EMBEDDED = 2;
    }
}

/// The (unique) sender of a backend method call.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Caller(pub String);

/// The live unique owner of the well-known frontend name looked up at call
/// time via the bus driver. Caller-supplied app IDs are not credentials.
#[derive(Clone, Debug)]
pub struct FrontendOwner(pub String);

/// Decides whether a message sender may call backend methods. Only the
/// current unique owner of `org.freedesktop.portal.Desktop` is accepted;
/// session-bus unique names cannot be forged by clients.
pub fn caller_is_frontend(sender: Option<&Caller>, owner: Option<&FrontendOwner>) -> bool {
    match (sender, owner) {
        (Some(sender), Some(owner)) => sender.0 == owner.0,
        _ => false,
    }
}

/// The results part of every backend response pair: `a{sv}`.
pub type PortalDict = HashMap<String, OwnedValue>;

/// `(response, results)` mirroring the backend contract tuples.
#[derive(Debug)]
pub struct PortalReply {
    pub response: u32,
    pub results: PortalDict,
}

impl PortalReply {
    pub fn new(response: u32, results: PortalDict) -> Self {
        Self { response, results }
    }

    /// Success with an empty results dictionary (CreateSession contract).
    pub fn ok() -> Self {
        Self::new(RESPONSE_OK, PortalDict::new())
    }
}

/// Loop-side handle for answering one pending method call.
///
/// Senders must not block: this is an unbounded async channel, and the
/// event loop answers with `send_blocking`, which merely queues.
#[derive(Clone, Debug)]
pub struct ReplyLink {
    tx: async_channel::Sender<PortalReply>,
}

impl ReplyLink {
    pub fn send(self, reply: PortalReply) {
        let _ = self.tx.send_blocking(reply);
    }
}

pub type PendingReply = async_channel::Receiver<PortalReply>;

pub(crate) fn make_reply_pair() -> (ReplyLink, PendingReply) {
    let (tx, rx) = async_channel::unbounded();
    (ReplyLink { tx }, rx)
}

async fn wait_reply(queue: PendingReply) -> zbus::fdo::Result<(u32, PortalDict)> {
    match queue.recv().await {
        Ok(reply) => Ok((reply.response, reply.results)),
        Err(_) => Err(zbus::fdo::Error::Failed("reply channel closed".into())),
    }
}

/// A validated portal request that the event loop must complete.
#[derive(Debug)]
pub enum PortalCall {
    CreateSession {
        handle: OwnedObjectPath,
        session_handle: OwnedObjectPath,
        app_id: String,
        caller: Option<Caller>,
        reply: ReplyLink,
    },
    SelectSources {
        handle: OwnedObjectPath,
        session_handle: OwnedObjectPath,
        app_id: String,
        constraints: ScreenCastConstraints,
        caller: Option<Caller>,
        reply: ReplyLink,
    },
    Start {
        handle: OwnedObjectPath,
        session_handle: OwnedObjectPath,
        app_id: String,
        parent_window: String,
        constraints: ScreenCastConstraints,
        caller: Option<Caller>,
        reply: ReplyLink,
    },
    RequestClose {
        handle: OwnedObjectPath,
        caller: Option<Caller>,
        reply: ReplyLink,
    },
    /// Live ownership update of `org.freedesktop.portal.Desktop`, bridged
    /// from the bus driver's NameOwnerChanged signal. `None` is a frontend
    /// loss (everything closes); `Some(owner)` re-binds authorization.
    /// The startup `get_name_owner` seed is best effort: a fresh login
    /// starts the backend before the frontend claims its name, and only
    /// this event ever supplies the real owner.
    FrontendOwnerChanged { owner: Option<FrontendOwner> },
}

/// Validated ScreenCast request options. Defaults follow the portal
/// contract: missing types default to MONITOR, missing cursor to Hidden.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScreenCastConstraints {
    pub types: SourceTypes,
    pub cursor_mode: CursorModes,
    pub multiple: bool,
    pub restore_token: Option<String>,
}

/// Validates and defaults the ScreenCast option dictionary of
/// SelectSources/Start.
///
/// An Err must surface to the frontend as response code 2 (or a D-Bus
/// error), never panic: a malicious or buggy frontend must not be able to
/// crash the compositor.
fn lookup_u32(options: &PortalDict, key: &str) -> Option<u32> {
    let value = options.get(key)?;
    u32::try_from(value.clone()).ok()
}

fn lookup_bool(options: &PortalDict, key: &str) -> Option<bool> {
    let value = options.get(key)?;
    bool::try_from(value.clone()).ok()
}

fn lookup_string(options: &PortalDict, key: &str) -> Option<String> {
    let value = options.get(key)?;
    String::try_from(value.clone()).ok()
}

pub fn parse_screen_cast_constraints(
    options: &PortalDict,
    available: SourceTypes,
) -> Result<ScreenCastConstraints, String> {
    let mut constraints = ScreenCastConstraints {
        types: SourceTypes::MONITOR,
        cursor_mode: CursorModes::HIDDEN,
        multiple: false,
        restore_token: None,
    };

    if let Some(requested) = lookup_u32(options, "types") {
        let requested = SourceTypes::from_bits(requested)
            .ok_or_else(|| "Invalid requested source types".to_string())?;
        if requested.is_empty() {
            return Err("Invalid requested source types".to_string());
        }
        let intersection = SourceTypes::from_bits(requested.bits() & available.bits())
            .expect("non-empty masked source types");
        if intersection.is_empty() {
            return Err("Requested sources are unavailable".to_string());
        }
        constraints.types = intersection;
    }

    if let Some(requested) = lookup_u32(options, "cursor_mode") {
        let mode = CursorModes::from_bits(requested)
            .ok_or_else(|| "Invalid requested cursor mode".to_string())?;
        if mode.is_empty() {
            return Err("Invalid requested cursor mode".to_string());
        }
        constraints.cursor_mode = mode;
    }

    if let Some(multiple) = lookup_bool(options, "multiple") {
        constraints.multiple = multiple;
    }

    constraints.restore_token = lookup_string(options, "restore_token");

    Ok(constraints)
}

struct ScreenCastBackend {
    calls: calloop::channel::Sender<PortalCall>,
}

#[interface(name = "org.freedesktop.impl.portal.ScreenCast")]
impl ScreenCastBackend {
    #[zbus(property, name = "AvailableCursorModes")]
    fn available_cursor_modes(&self) -> u32 {
        (CursorModes::HIDDEN | CursorModes::EMBEDDED).bits()
    }

    #[zbus(property, name = "AvailableSourceTypes")]
    fn available_source_types(&self) -> u32 {
        SourceTypes::MONITOR.bits()
    }

    #[zbus(property, name = "version")]
    fn version(&self) -> u32 {
        SCREENCAST_BACKEND_VERSION
    }

    async fn create_session(
        &self,
        #[zbus(header)] header: Header<'_>,
        handle: ObjectPath<'_>,
        session_handle: ObjectPath<'_>,
        app_id: String,
        _options: PortalDict,
    ) -> zbus::fdo::Result<(u32, PortalDict)> {
        let handle = OwnedObjectPath::from(handle);
        let session_handle = OwnedObjectPath::from(session_handle);
        let caller = header.sender().map(|sender| Caller(sender.to_string()));
        let (reply, pending) = make_reply_pair();
        self.calls
            .send(PortalCall::CreateSession {
                handle,
                session_handle,
                app_id,
                caller,
                reply,
            })
            .map_err(|_| stopped_error())?;
        wait_reply(pending).await
    }

    async fn select_sources(
        &self,
        #[zbus(header)] header: Header<'_>,
        handle: ObjectPath<'_>,
        session_handle: ObjectPath<'_>,
        app_id: String,
        options: PortalDict,
    ) -> zbus::fdo::Result<(u32, PortalDict)> {
        // Contract: SelectSources stores/validates constraints, it does
        // not grant consent.
        let constraints = match parse_screen_cast_constraints(&options, SourceTypes::MONITOR) {
            Ok(constraints) => constraints,
            Err(message) => {
                tracing::debug!(message, "Rejecting SelectSources options");
                return Ok((RESPONSE_FAILED, PortalDict::new()));
            }
        };
        let handle = OwnedObjectPath::from(handle);
        let session_handle = OwnedObjectPath::from(session_handle);
        let caller = header.sender().map(|sender| Caller(sender.to_string()));
        let (reply, pending) = make_reply_pair();
        self.calls
            .send(PortalCall::SelectSources {
                handle,
                session_handle,
                app_id,
                constraints,
                caller,
                reply,
            })
            .map_err(|_| stopped_error())?;
        wait_reply(pending).await
    }

    async fn start(
        &self,
        #[zbus(header)] header: Header<'_>,
        handle: ObjectPath<'_>,
        session_handle: ObjectPath<'_>,
        app_id: String,
        parent_window: String,
        options: PortalDict,
    ) -> zbus::fdo::Result<(u32, PortalDict)> {
        let constraints = match parse_screen_cast_constraints(&options, SourceTypes::MONITOR) {
            Ok(constraints) => constraints,
            Err(message) => {
                tracing::debug!(message, "Rejecting Start options");
                return Ok((RESPONSE_FAILED, PortalDict::new()));
            }
        };
        let handle = OwnedObjectPath::from(handle);
        let session_handle = OwnedObjectPath::from(session_handle);
        let caller = header.sender().map(|sender| Caller(sender.to_string()));
        let (reply, pending) = make_reply_pair();
        self.calls
            .send(PortalCall::Start {
                handle,
                session_handle,
                app_id,
                parent_window,
                constraints,
                caller,
                reply,
            })
            .map_err(|_| stopped_error())?;
        wait_reply(pending).await
    }
}

/// Backend `Request` object for one pending response: `Close` travels
/// through the same bridge so the loop can invalidate the matching late
/// reply instead of publishing a node for a cancelled request.
struct RequestBackend {
    calls: calloop::channel::Sender<PortalCall>,
}

#[interface(name = "org.freedesktop.impl.portal.Request")]
impl RequestBackend {
    async fn close(&self, #[zbus(header)] header: Header<'_>) -> zbus::fdo::Result<()> {
        let Some(object_path) = header.path() else {
            return Err(invalid_parameters());
        };
        let handle = OwnedObjectPath::from(object_path.clone());
        let caller = header.sender().map(|sender| Caller(sender.to_string()));
        let (reply, pending) = make_reply_pair();
        self.calls
            .send(PortalCall::RequestClose {
                handle,
                caller,
                reply,
            })
            .map_err(|_| stopped_error())?;
        wait_reply(pending).await?;
        Ok(())
    }
}

// Session object lives at /org/freedesktop/portal/desktop/session/<sender>/<token>
#[allow(clippy::needless_lifetimes)]
struct SessionBackend {
    calls: calloop::channel::Sender<PortalCall>,
}

impl SessionBackend {
    fn new(calls: calloop::channel::Sender<PortalCall>) -> Self {
        Self { calls }
    }
}

impl RequestBackend {
    fn new(calls: calloop::channel::Sender<PortalCall>) -> Self {
        Self { calls }
    }
}

fn invalid_parameters() -> zbus::fdo::Error {
    zbus::fdo::Error::InvalidArgs("invalid call arguments".into())
}

fn stopped_error() -> zbus::fdo::Error {
    zbus::fdo::Error::Failed("backend service stopped".into())
}

/// Service-local helper for the object bridge: Session/Request objects get
/// their sender explicitly through [serve_object_bridge]-time construction.
#[derive(Clone)]
struct PortalDials {
    calls: calloop::channel::Sender<PortalCall>,
}

thread_local! {
    static BRIDGE_CALLS: std::cell::OnceCell<calloop::channel::Sender<PortalCall>> =
        std::cell::OnceCell::new();
}

fn connection_calls_of() -> Option<calloop::channel::Sender<PortalCall>> {
    BRIDGE_CALLS.with(|calls| calls.get().cloned())
}

#[interface(name = "org.freedesktop.impl.portal.Session")]
impl SessionBackend {
    #[zbus(property, name = "version")]
    fn version(&self) -> u32 {
        REQUEST_SESSION_VERSION
    }

    async fn close(&self, #[zbus(header)] header: Header<'_>) -> zbus::fdo::Result<()> {
        let Some(object_path) = header.path() else {
            return Err(invalid_parameters());
        };
        let handle = OwnedObjectPath::from(object_path.clone());
        let caller = header.sender().map(|sender| Caller(sender.to_string()));
        let (reply, pending) = make_reply_pair();
        self.calls
            .send(PortalCall::RequestClose {
                handle,
                caller,
                reply,
            })
            .map_err(|_| stopped_error())?;
        wait_reply(pending).await?;
        Ok(())
    }
}

/// The running compositor-wide portal backend: the call receiver consumed
/// by the event loop, the object-bridge handles, and the initial ledger
/// (frontend owner bound at startup).
pub struct PortalRuntime {
    pub objects: std::sync::mpsc::Sender<service::PortalAction>,
    pub ledger: service::PortalLedger,
}

/// Starts the backend on the session bus. Returns None when there is no
/// usable session bus (never silently degrading; the caller decides what a
/// missing bus means for this run), and hands the call receiver to whoever
/// registers it on the event loop.
pub fn spawn_portal_runtime() -> Option<zbus::Result<(PortalRuntime, CallReceiver)>> {
    Some(zbus::block_on(start_portal_backend()))
}

async fn start_portal_backend() -> zbus::Result<(PortalRuntime, CallReceiver)> {
    let (connection, calls, receiver) = build_backend_connection_on_session().await?;
    // The initial frontend owner is bound to the service: requests answered
    // before the owner is known are rejected, so this runs first.
    // Best effort only: on a fresh login the frontend may not have
    // claimed its name yet; the NameOwnerChanged subscription below
    // supplies the real owner the moment it appears.
    let driver = zbus::fdo::DBusProxy::new(&connection).await?;
    let frontend_owner = driver
        .get_name_owner(zbus::names::BusName::try_from(FRONTEND_NAME)? as zbus::names::BusName)
        .await
        .map(|name| FrontendOwner(name.to_string()));

    // Live frontend owner: every restart of the frontend (and its
    // first appearance) changes the unique name the backend must
    // authenticate against. The subscription is serviced by this
    // connection's internal executor and bridged onto the compositor
    // loop channel; ledger mutation stays loop-side.
    let mut subscription = driver
        .receive_name_owner_changed()
        .await
        .map_err(|error| zbus::Error::Failure(error.to_string()))?;
    let calls_for_events = calls.clone();
    // The subscription stream is async; this thread block_on-drives it
    // exactly like the object bridge drives its async actions. Only
    // owner names cross here, never compositor state and never pixels.
    std::thread::spawn(move || {
        while let Some(event) = zbus::block_on(subscription.next()) {
            let Ok(args) = event.args() else {
                continue;
            };
            if args.name() != FRONTEND_NAME {
                continue;
            }
            let owner = args
                .new_owner()
                .as_ref()
                // An empty new owner is how the driver reports loss.
                .filter(|new| !new.as_str().is_empty())
                .map(|new| FrontendOwner(new.to_string()));
            if calls_for_events
                .send(PortalCall::FrontendOwnerChanged { owner })
                .is_err()
            {
                return;
            }
        }
        tracing::warn!("frontend ownership watch ended");
    });

    let objects_tx = spawn_object_bridge(&connection, &calls);
    let runtime = PortalRuntime {
        objects: objects_tx,
        ledger: service::PortalLedger {
            frontend: frontend_owner.ok(),
            ..Default::default()
        },
    };
    Ok((runtime, receiver))
}

/// Starts the object bridge thread: Dispatches Session/Request export- and
/// close-level actions away from the compositor loop.
fn spawn_object_bridge(
    connection: &Connection,
    calls: &calloop::channel::Sender<PortalCall>,
) -> std::sync::mpsc::Sender<service::PortalAction> {
    let (objects_tx, objects_rx) = std::sync::mpsc::channel::<service::PortalAction>();
    let bridge_connection = connection.clone();
    let bridge_calls = calls.clone();
    std::thread::spawn(move || serve_object_bridge(bridge_connection, bridge_calls, objects_rx));
    objects_tx
}

async fn build_backend_connection_on_session() -> zbus::Result<(
    Connection,
    calloop::channel::Sender<PortalCall>,
    CallReceiver,
)> {
    let (calls, receiver) = calloop::channel::channel::<PortalCall>();
    let connection = ConnectionBuilder::session()?
        .name(BACKEND_NAME)?
        .serve_at(
            DESKTOP_PATH,
            ScreenCastBackend {
                calls: calls.clone(),
            },
        )?
        .build()
        .await?;
    Ok((connection, calls, receiver))
}

/// The object bridge: every Session/Request object is served on this
/// dedicated thread via block_on, keeping compositor code off async. It
/// carries only paths, never pixels and never state mutation.
fn serve_object_bridge(
    connection: Connection,
    calls: calloop::channel::Sender<PortalCall>,
    objects: std::sync::mpsc::Receiver<service::PortalAction>,
) {
    while let Ok(action) = objects.recv() {
        if let Err(error) = zbus::block_on(perform_bridge_action(&connection, &calls, action)) {
            tracing::warn!(?error, "portal object bridge action failed");
        }
    }
}

async fn perform_bridge_action(
    connection: &Connection,
    calls: &calloop::channel::Sender<PortalCall>,
    action: service::PortalAction,
) -> zbus::Result<()> {
    let object_server = connection.object_server();
    match action {
        service::PortalAction::ExportSession(session_handle) => {
            object_server
                .at(session_handle.as_str(), SessionBackend::new(calls.clone()))
                .await?;
        }
        service::PortalAction::ExportRequest(handle) => {
            object_server
                .at(handle.as_str(), RequestBackend::new(calls.clone()))
                .await?;
        }
        service::PortalAction::CloseSession(session_handle) => {
            // Signal first: the `Closed()` signal must appear before the
            // object disappears.
            connection
                .emit_signal(
                    Option::<zbus::names::BusName>::None,
                    session_handle.as_str(),
                    SESSION_INTERFACE,
                    "Closed",
                    &(),
                )
                .await?;
        }
        service::PortalAction::UnexportSession(session_handle) => {
            object_server
                .remove::<SessionBackend, _>(session_handle.as_str())
                .await?;
        }
        service::PortalAction::UnexportRequest(handle) => {
            object_server
                .remove::<RequestBackend, _>(handle.as_str())
                .await?;
        }
    }
    Ok(())
}

/// Builds a screen-cast backend service connection.
///
/// The returned `Connection` runs its internal executor on its own thread
/// but does nothing compositor-related on its own: every method call is
/// pushed to `calls` and answered only from there.
pub async fn build_backend_connection(
    address: &str,
) -> Result<
    (
        Connection,
        calloop::channel::Sender<PortalCall>,
        CallReceiver,
    ),
    zbus::Error,
> {
    let (tx, rx) = calloop::channel::channel::<PortalCall>();
    let connection = ConnectionBuilder::address(address)?
        .name(BACKEND_NAME)?
        .serve_at(DESKTOP_PATH, ScreenCastBackend { calls: tx.clone() })?
        .build()
        .await?;
    Ok((connection, tx, rx))
}

/// Unit tests for the pure pieces: constraint parsing and frontend
/// authorization. The runtime D-Bus behavior against a fake frontend runs
/// from the harness test that spawns an isolated session bus.
#[allow(clippy::needless_borrows_for_generic_args)]
mod unit_tests {
    use super::*;

    #[test]
    fn only_the_live_frontend_owner_passes() {
        let owner = FrontendOwner(":1.23".into());
        assert!(caller_is_frontend(
            Some(&Caller(":1.23".into())),
            Some(&owner)
        ));
        assert!(!caller_is_frontend(
            Some(&Caller(":1.99".into())),
            Some(&owner)
        ));
        assert!(!caller_is_frontend(None, Some(&owner)));
        assert!(!caller_is_frontend(Some(&Caller(":1.23".into())), None));
        assert!(!caller_is_frontend(None, None));
    }

    fn options(entries: &[(&str, OwnedValue)]) -> PortalDict {
        entries
            .iter()
            .map(|(key, value)| (key.to_string(), value.clone()))
            .collect()
    }

    #[test]
    fn missing_types_default_to_monitor_and_hidden_cursor() {
        let constraints = parse_screen_cast_constraints(&PortalDict::new(), SourceTypes::MONITOR)
            .expect("defaults");
        assert_eq!(constraints.types, SourceTypes::MONITOR);
        assert_eq!(constraints.cursor_mode, CursorModes::HIDDEN);
        assert!(!constraints.multiple);
        assert_eq!(constraints.restore_token, None);
    }

    #[test]
    fn window_only_request_is_rejected_at_monitor_stage() {
        let requested = parse_screen_cast_constraints(
            &options(&[("types", OwnedValue::from(SourceTypes::WINDOW.bits()))]),
            SourceTypes::MONITOR,
        );
        assert!(requested.is_err());
    }

    #[test]
    fn virtual_only_request_fails_without_panic() {
        let requested = parse_screen_cast_constraints(
            &options(&[("types", OwnedValue::from(SourceTypes::VIRTUAL.bits()))]),
            SourceTypes::MONITOR,
        );
        assert!(requested.is_err());
    }

    #[test]
    fn empty_types_request_is_rejected() {
        let requested = parse_screen_cast_constraints(
            &options(&[("types", OwnedValue::from(0u32))]),
            SourceTypes::MONITOR,
        );
        assert!(requested.is_err());
    }

    #[test]
    fn invalid_cursor_mode_is_rejected() {
        assert!(parse_screen_cast_constraints(
            &options(&[("cursor_mode", OwnedValue::from(0u32))]),
            SourceTypes::MONITOR
        )
        .is_err());
        assert!(parse_screen_cast_constraints(
            &options(&[("cursor_mode", OwnedValue::from(7u32))]),
            SourceTypes::MONITOR
        )
        .is_err());
    }

    #[test]
    fn complete_request_is_accepted() {
        let constraints = parse_screen_cast_constraints(
            &options(&[
                ("types", OwnedValue::from(SourceTypes::MONITOR.bits())),
                (
                    "cursor_mode",
                    OwnedValue::from(CursorModes::EMBEDDED.bits()),
                ),
                ("multiple", OwnedValue::from(true)),
                (
                    "restore_token",
                    OwnedValue::from(zbus::zvariant::Str::from("t0")),
                ),
            ]),
            SourceTypes::MONITOR,
        )
        .expect("valid options");
        assert_eq!(constraints.types, SourceTypes::MONITOR);
        assert_eq!(constraints.cursor_mode, CursorModes::EMBEDDED);
        assert!(constraints.multiple);
        assert_eq!(constraints.restore_token.as_deref(), Some("t0"));
    }
}

/// Turns an `ObjectServer` handle into a typed accessor for later milestone
/// wiring.
pub type CallReceiver = calloop::channel::Channel<PortalCall>;
