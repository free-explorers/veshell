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
pub const SCREENSHOT_INTERFACE: &str = "org.freedesktop.impl.portal.Screenshot";
pub const REQUEST_INTERFACE: &str = "org.freedesktop.impl.portal.Request";
pub const SESSION_INTERFACE: &str = "org.freedesktop.impl.portal.Session";

/// ScreenCast backend contract version advertised by Veshell.
pub const SCREENCAST_BACKEND_VERSION: u32 = 4;
/// Vendor string inside the backend-facing `restore_data (suv)` blob. The
/// xdg-desktop-portal frontend stores this blob opaquely, translates it into
/// the client-facing `restore_token` string, and translates it back on a later
/// SelectSources. A foreign vendor (for example another desktop's backend)
/// must degrade to "no restore" and the ordinary prompt.
pub const RESTORE_DATA_VENDOR: &str = "veshell";
/// Version of the private payload inside the `(suv)` vendor tuple.
pub const RESTORE_DATA_VERSION: u32 = 1;
/// Screenshot backend contract version advertised by Veshell: version 3
/// carries the `Target` and the `AvailableTargets` property.
pub const SCREENSHOT_BACKEND_VERSION: u32 = 3;
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
        /// The raw Start options dictionary: the ledger needs to know
        /// which keys the frontend actually sent, because a missing
        /// `types` key must fall back to the SelectSources-stored
        /// constraints instead of the parse defaults (the live Chromium
        /// flow stores `types: 3` in SelectSources and sends Start
        /// without keys — the parse default would clobber the WINDOW
        /// kinds out of the picker).
        options: PortalDict,
        caller: Option<Caller>,
        reply: ReplyLink,
    },
    RequestClose {
        handle: OwnedObjectPath,
        caller: Option<Caller>,
        reply: ReplyLink,
    },
    /// A portal screenshot request (spec section 8.4): one full-screen
    /// PNG per request, gated by the trusted prompt like every other
    /// capture flow. The reply completes after the user decides and the
    /// encode finishes.
    Screenshot {
        handle: OwnedObjectPath,
        app_id: String,
        parent_window: String,
        options: PortalDict,
        caller: Option<Caller>,
        reply: ReplyLink,
    },
    /// A portal color-pick request: the same consent gate, answered with
    /// the sampled pixel instead of a file.
    PickColor {
        handle: OwnedObjectPath,
        app_id: String,
        parent_window: String,
        options: PortalDict,
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
    /// The `persist_mode` the client asked for (portal contract): 0 none,
    /// 1 transient, 2 persistent. The backend supports transient grants
    /// only and answers with what it granted in the Start result.
    pub persist_mode: u32,
    /// The client's restore token, recovered from the backend-facing
    /// `restore_data (suv)` blob that the frontend exchanged for the
    /// client's opaque `restore_token` string. Portal implementations never
    /// see the token itself: the frontend translates both ways (see
    /// `encode_restore_data`). An unguessable token grants no access by
    /// itself: every use revalidates against the live frontend owner and
    /// live source registries.
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

/// Wraps the backend's unguessable restore token in the `(suv)` blob the
/// xdg-desktop-portal frontend exchanges with implementations: vendor,
/// format version, and an implementation-private variant. The frontend turns
/// this into the client's opaque `restore_token` string and hands the same
/// blob back on a later SelectSources, where `lookup_restore_token` unwraps
/// it again.
pub fn encode_restore_data(token: &str) -> Option<OwnedValue> {
    use zbus::zvariant::{Str, StructureBuilder, Value};
    // `add_field` runs `Value::new` internally, so the private payload is
    // appended as an already-built variant to keep it a single `v` field.
    let structure = StructureBuilder::new()
        .add_field(RESTORE_DATA_VENDOR)
        .add_field(RESTORE_DATA_VERSION)
        .append_field(Value::Value(Box::new(Value::Str(Str::from(token)))))
        .build()
        .ok()?;
    OwnedValue::try_from(Value::Structure(structure)).ok()
}

/// Parses the backend-facing `restore_data (suv)` blob down to Veshell's
/// restore token. Non-`(suv)` values, foreign vendors, newer private formats,
/// and empty payloads are ignored rather than fatal: unreadable restore data
/// must degrade to "no restore" and the ordinary prompt, never to a rejected
/// request.
fn lookup_restore_token(options: &PortalDict) -> Option<String> {
    use zbus::zvariant::{Signature, Value};
    let raw = options.get("restore_data")?;
    let Value::Structure(structure) = Value::from(raw.clone()) else {
        return None;
    };
    if structure.signature()
        != &Signature::structure([Signature::Str, Signature::U32, Signature::Variant])
    {
        return None;
    }
    let fields = structure.fields();
    let [vendor, version, payload] = fields else {
        return None;
    };
    let Value::Str(vendor) = vendor else {
        return None;
    };
    if vendor.as_str() != RESTORE_DATA_VENDOR {
        return None;
    }
    let Value::U32(version) = version else {
        return None;
    };
    if *version > RESTORE_DATA_VERSION {
        return None;
    }
    let Value::Value(payload) = payload else {
        return None;
    };
    let Value::Str(token) = &**payload else {
        return None;
    };
    (!token.is_empty()).then(|| token.to_string())
}

pub fn parse_screen_cast_constraints(
    options: &PortalDict,
    available: SourceTypes,
) -> Result<ScreenCastConstraints, String> {
    let mut constraints = ScreenCastConstraints {
        types: SourceTypes::MONITOR,
        cursor_mode: CursorModes::HIDDEN,
        multiple: false,
        persist_mode: 0,
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

    if let Some(mode) = lookup_u32(options, "persist_mode") {
        // The backend grants transient (1) when the client asks for any
        // persistence; unknown mode values are invalid per contract.
        if mode > 2 {
            return Err("Invalid persist_mode".to_string());
        }
        constraints.persist_mode = mode;
    }

    // The frontend replaces the client's `restore_token` with the backend
    // `restore_data (suv)` blob it stored earlier. The legacy top-level
    // `restore_token` key is unreachable through the real frontend but stays
    // accepted defensively.
    constraints.restore_token =
        lookup_restore_token(options).or_else(|| lookup_string(options, "restore_token"));
    if constraints.restore_token.is_some() {
        tracing::debug!("Portal options carry RestoreData (or a top-level restore token)");
    }

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
        // Both implemented source kinds (spec 8.1): M2's outputs and M4's
        // windows. Screen sharing joins through the MONITOR picker group
        // in M5 and does not change this value.
        (SourceTypes::MONITOR | SourceTypes::WINDOW).bits()
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
        // not grant consent. The advertisement carries every implemented
        // source kind (spec 8.1: advertise MONITOR | WINDOW once both
        // implementations work; M2 outputs, M4 windows).
        let constraints = match parse_screen_cast_constraints(
            &options,
            SourceTypes::MONITOR | SourceTypes::WINDOW,
        ) {
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
        let constraints = match parse_screen_cast_constraints(
            &options,
            SourceTypes::MONITOR | SourceTypes::WINDOW,
        ) {
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
                options,
                caller,
                reply,
            })
            .map_err(|_| stopped_error())?;
        wait_reply(pending).await
    }
}

/// The Screenshot backend: `Screenshot` and `PickColor` per the version-3
/// contract. Both methods block until the loop answers (prompt decision
/// and capture included), mirroring how the ScreenCast methods wait for
/// the ledger. Only full-screen targets are supported this milestone.
struct ScreenshotBackend {
    calls: calloop::channel::Sender<PortalCall>,
}

/// Targets advertised by this backend: Screen only (spec 8.4 initial
/// slice). The host must never request the rejected targets; a targeted
/// request that still arrives fails with response code 2.
pub const SCREENSHOT_TARGET_SCREEN: u32 = 1;

/// Validates the Screenshot options: `interactive`/`modal` booleans, and
/// the optional `target` filter. The result dict is untouched.
struct ScreenshotOptions {
    interactive: bool,
    modal: bool,
    target: Option<u32>,
}

fn parse_screenshot_options(options: &PortalDict) -> Result<ScreenshotOptions, String> {
    let mut parsed = ScreenshotOptions {
        interactive: false,
        modal: true,
        target: None,
    };
    if let Some(interactive) = lookup_bool(options, "interactive") {
        parsed.interactive = interactive;
    }
    if let Some(modal) = lookup_bool(options, "modal") {
        parsed.modal = modal;
    }
    if let Some(target) = lookup_u32(options, "target") {
        if target != SCREENSHOT_TARGET_SCREEN {
            return Err("Requested screenshot target is unavailable".to_string());
        }
        parsed.target = Some(target);
    }
    Ok(parsed)
}

#[interface(name = "org.freedesktop.impl.portal.Screenshot")]
impl ScreenshotBackend {
    #[zbus(property, name = "AvailableTargets")]
    fn available_targets(&self) -> u32 {
        SCREENSHOT_TARGET_SCREEN
    }

    #[zbus(property, name = "version")]
    fn version(&self) -> u32 {
        SCREENSHOT_BACKEND_VERSION
    }

    async fn screenshot(
        &self,
        #[zbus(header)] header: Header<'_>,
        handle: ObjectPath<'_>,
        app_id: String,
        parent_window: String,
        options: PortalDict,
    ) -> zbus::fdo::Result<(u32, PortalDict)> {
        if let Err(message) = parse_screenshot_options(&options) {
            tracing::debug!(message, "Rejecting Screenshot options");
            return Ok((RESPONSE_FAILED, PortalDict::new()));
        }
        let handle = OwnedObjectPath::from(handle);
        let caller = header.sender().map(|sender| Caller(sender.to_string()));
        let (reply, pending) = make_reply_pair();
        self.calls
            .send(PortalCall::Screenshot {
                handle,
                app_id,
                parent_window,
                options,
                caller,
                reply,
            })
            .map_err(|_| stopped_error())?;
        wait_reply(pending).await
    }

    async fn pick_color(
        &self,
        #[zbus(header)] header: Header<'_>,
        handle: ObjectPath<'_>,
        app_id: String,
        parent_window: String,
        options: PortalDict,
    ) -> zbus::fdo::Result<(u32, PortalDict)> {
        if let Err(message) = parse_screenshot_options(&options) {
            tracing::debug!(message, "Rejecting PickColor options");
            return Ok((RESPONSE_FAILED, PortalDict::new()));
        }
        let handle = OwnedObjectPath::from(handle);
        let caller = header.sender().map(|sender| Caller(sender.to_string()));
        let (reply, pending) = make_reply_pair();
        self.calls
            .send(PortalCall::PickColor {
                handle,
                app_id,
                parent_window,
                options,
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
        .serve_at(
            DESKTOP_PATH,
            ScreenshotBackend {
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
        .serve_at(DESKTOP_PATH, ScreenshotBackend { calls: tx.clone() })?
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
    fn window_only_request_is_accepted() {
        let requested = parse_screen_cast_constraints(
            &options(&[("types", OwnedValue::from(SourceTypes::WINDOW.bits()))]),
            SourceTypes::MONITOR | SourceTypes::WINDOW,
        )
        .expect("windows are implemented sources");
        assert_eq!(requested.types, SourceTypes::WINDOW);
    }

    #[test]
    fn virtual_only_request_fails_without_panic() {
        let requested = parse_screen_cast_constraints(
            &options(&[("types", OwnedValue::from(SourceTypes::VIRTUAL.bits()))]),
            SourceTypes::MONITOR | SourceTypes::WINDOW,
        );
        assert!(requested.is_err());
    }

    #[test]
    fn empty_types_request_is_rejected() {
        let requested = parse_screen_cast_constraints(
            &options(&[("types", OwnedValue::from(0u32))]),
            SourceTypes::MONITOR | SourceTypes::WINDOW,
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
        assert_eq!(constraints.persist_mode, 0);
    }

    /// Builds the `(suv)` wire shape directly so tests pin the contract
    /// independent of the production encoder.
    fn restore_data(vendor: &str, version: u32, token: &str) -> OwnedValue {
        let structure = zbus::zvariant::StructureBuilder::new()
            .add_field(vendor)
            .add_field(version)
            .append_field(zbus::zvariant::Value::Value(Box::new(
                zbus::zvariant::Value::Str(zbus::zvariant::Str::from(token)),
            )))
            .build()
            .expect("restore_data structure");
        OwnedValue::try_from(zbus::zvariant::Value::Structure(structure)).expect("owned value")
    }

    // The backend-facing contract: `restore_data` is `(suv)` (vendor,
    // version, private payload). The frontend translates the client's
    // `restore_token` string into this blob; the backend never sees the
    // token itself.
    #[test]
    fn restore_data_suv_parses_down_to_the_token() {
        let constraints = parse_screen_cast_constraints(
            &options(&[
                ("persist_mode", OwnedValue::from(2u32)),
                ("restore_data", restore_data("veshell", 1, "veshell-grant")),
            ]),
            SourceTypes::MONITOR | SourceTypes::WINDOW,
        )
        .expect("valid options");
        assert_eq!(constraints.restore_token.as_deref(), Some("veshell-grant"));
        assert_eq!(constraints.persist_mode, 2);
    }

    #[test]
    fn encoded_restore_data_round_trips() {
        let encoded = super::encode_restore_data("round-trip").expect("encodes");
        let constraints = parse_screen_cast_constraints(
            &options(&[("restore_data", encoded)]),
            SourceTypes::MONITOR,
        )
        .expect("valid options");
        assert_eq!(constraints.restore_token.as_deref(), Some("round-trip"));
    }

    // A blob from another portal implementation (for example after a
    // desktop switch) must degrade to "no restore", never to a rejection.
    #[test]
    fn foreign_vendor_restore_data_is_ignored() {
        let constraints = parse_screen_cast_constraints(
            &options(&[("restore_data", restore_data("GNOME", 1, "gnome-grant"))]),
            SourceTypes::MONITOR,
        )
        .expect("restore data is never fatal");
        assert_eq!(constraints.restore_token, None);
    }

    #[test]
    fn newer_restore_data_format_is_ignored() {
        let constraints = parse_screen_cast_constraints(
            &options(&[("restore_data", restore_data("veshell", 2, "future"))]),
            SourceTypes::MONITOR,
        )
        .expect("restore data is never fatal");
        assert_eq!(constraints.restore_token, None);
    }

    // Not-a-`(suv)` restore data degrades to "no restore": it must never
    // turn a valid request into a rejection.
    #[test]
    fn malformed_restore_data_is_ignored() {
        let wrong_shape = zbus::zvariant::StructureBuilder::new()
            .add_field(zbus::zvariant::Value::U32(1))
            .add_field(zbus::zvariant::Value::U32(1))
            .add_field(zbus::zvariant::Value::U32(1))
            .build()
            .expect("structure");
        let wrong_shape =
            OwnedValue::try_from(zbus::zvariant::Value::Structure(wrong_shape)).expect("owned");
        for malformed in [OwnedValue::from(true), OwnedValue::from(7u32), wrong_shape] {
            let constraints = parse_screen_cast_constraints(
                &options(&[("restore_data", malformed)]),
                SourceTypes::MONITOR,
            )
            .expect("restore data is never fatal");
            assert_eq!(constraints.restore_token, None);
        }
    }

    #[test]
    fn invalid_persist_mode_is_rejected() {
        assert!(parse_screen_cast_constraints(
            &options(&[("persist_mode", OwnedValue::from(7u32))]),
            SourceTypes::MONITOR,
        )
        .is_err());
    }
}

/// Turns an `ObjectServer` handle into a typed accessor for later milestone
/// wiring.
pub type CallReceiver = calloop::channel::Channel<PortalCall>;
