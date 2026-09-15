//! The portal session state machine.
//!
//! Owns no D-Bus plumbing: the lifecycle operates on a plain ledger so the
//! rules can be unit-tested without a session bus. Object-level side
//! effects are queued as [PortalAction]s for a dedicated object-bridge
//! thread; the compositor event loop never calls into zbus directly and
//! zbus handlers never touch compositor state.

use serde_json::json;
use zbus::zvariant::OwnedObjectPath;

use super::{
    caller_is_frontend, make_reply_pair, Caller, PendingReply, PortalCall, PortalReply, ReplyLink,
    ScreenCastConstraints, SourceTypes, RESPONSE_CANCELLED, RESPONSE_FAILED, RESPONSE_OK,
};

pub use super::FrontendOwner;

/// Portal session lifecycle (capture specification section 8.3).
///
/// PipeWire transport state is tracked separately from authorization in the
/// producer milestone; nothing here assumes delivery is running.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SessionState {
    Created,
    Configured,
    Choosing,
    Starting,
    Active,
    Closed,
}

/// An authorized capture session known to the backend.
#[derive(Clone, Debug)]
pub struct PortalSession {
    pub state: SessionState,
    pub constraints: Option<ScreenCastConstraints>,
}

/// A pending backend response remembered until it is completed or the user
/// closes its request object.
#[derive(Debug)]
pub struct PendingRequest {
    pub session_handle: OwnedObjectPath,
    pub cancelled: bool,
    /// While the trusted picker is open, Start's response waits. A link in
    /// the ledger means the picker owns this request's fate.
    ///
    /// The link itself is trusted shell state; D-Bus callers only see the
    /// ledger's minted unguessable [PendingRequest::consent_token] (capture
    /// specification section 8.3: picker replies bind to unguessable
    /// tokens).
    pub consent: Option<ConsentRequest>,
}

/// The consent picker a Start opened. Stamped with a token so late or
/// replayed consent replies cannot attach themselves to a live flow.
#[derive(Debug)]
pub struct ConsentRequest {
    pub consent_token: u64,
    pub app_name: String,
    /// Start's response, held until the user decides (or the request
    /// closes: then the link completes cancelled immediately).
    pub reply: ReplyLink,
}

/// Everything the backend service must know. Every nonclosed state can
/// close, and closing never redirects to a substitute target.
#[derive(Debug, Default)]
pub struct PortalLedger {
    pub sessions: HashMap<OwnedObjectPath, PortalSession>,
    pub requests: HashMap<OwnedObjectPath, PendingRequest>,
    pub frontend: Option<FrontendOwner>,
    pub next_consent_token: u64,
}

use std::collections::HashMap;

/// Object-level actions the loop hands to the object-bridge thread.
#[derive(Debug)]
pub enum PortalAction {
    ExportSession(OwnedObjectPath),
    ExportRequest(OwnedObjectPath),
    /// Emits `Closed()`. Unexporting arrives as the next action so the
    /// signal is observed while the object still exists.
    CloseSession(OwnedObjectPath),
    UnexportRequest(OwnedObjectPath),
    UnexportSession(OwnedObjectPath),
}

/// Trusted-shell actions the loop performs directly: the picker and the
/// indicator are compositor surfaces, opened and dismissed through the
/// platform channel to the Flutter shell.
#[derive(Debug)]
pub enum PortalUiEvent {
    OpenPicker {
        session_handle: OwnedObjectPath,
        request_handle: OwnedObjectPath,
        app_name: String,
        consent_token: u64,
    },
    DismissPicker {
        consent_token: u64,
    },
}

impl PortalLedger {
    /// Mints an unguessable consent token for a new picker.
    fn consent_token(&mut self) -> u64 {
        self.next_consent_token += 1;
        self.next_consent_token
    }
}

fn cancel_consent(request: &mut PendingRequest, ui: &mut Vec<PortalUiEvent>) {
    if let Some(consent) = request.consent.take() {
        consent.reply.send(cancelled());
        ui.push(PortalUiEvent::DismissPicker {
            consent_token: consent.consent_token,
        });
    }
}

/// Finds the consent bound to a session, if any: every close path (session
/// close, request close, frontend loss) dismisses the open picker.
/// A session that closes while its picker is open dismisses the picker
/// and completes the pending Start reply.
fn close_consent_for_session(
    ledger: &mut PortalLedger,
    session_handle: &OwnedObjectPath,
    ui: &mut Vec<PortalUiEvent>,
) {
    let handles: Vec<OwnedObjectPath> = ledger
        .requests
        .iter()
        .filter(|(_, request)| {
            request.consent.is_some() && request.session_handle.as_str() == session_handle.as_str()
        })
        .map(|(handle, _)| handle.clone())
        .collect();
    for handle in handles {
        if let Some(mut request) = ledger.requests.remove(&handle) {
            cancel_consent(&mut request, ui);
        }
    }
}

pub fn frontend_owner_changed(
    ledger: &mut PortalLedger,
    actions: &mut Vec<PortalAction>,
    ui: &mut Vec<PortalUiEvent>,
    owner: Option<FrontendOwner>,
) {
    let previous = ledger.frontend.as_ref().map(|current| current.0.clone());
    let next = owner.as_ref().map(|current| current.0.clone());
    let frontend_lost = owner.is_none();
    ledger.frontend = owner;
    if previous.is_some() && previous == next {
        return;
    }
    let open_consent: Vec<u64> = ledger
        .requests
        .values()
        .filter_map(|request| {
            request
                .consent
                .as_ref()
                .map(|consent| consent.consent_token)
        })
        .collect();
    for consent_token in open_consent {
        // The reply link already answered cancelled during the clearing
        // sweep below, since CancelRequest carries the link out with it.
        ui.push(PortalUiEvent::DismissPicker { consent_token });
    }
    for request in ledger.requests.values_mut() {
        if let Some(consent) = request.consent.take() {
            consent.reply.send(cancelled());
        }
    }
    ledger.requests.clear();
    let closed_sessions: Vec<OwnedObjectPath> = ledger.sessions.keys().cloned().collect();
    for session_handle in closed_sessions {
        ledger.sessions.remove(&session_handle);
        actions.push(PortalAction::CloseSession(session_handle.clone()));
    }
    if frontend_lost {
        tracing::info!("Portal frontend lost: all sessions closed");
    }
}

/// Compositor wiring: runs one bridged call against the runtime ledger and
/// dispatches the resulting object actions. Never called off the loop
/// thread.
pub fn handle_portal_call<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    call: PortalCall,
) {
    let Some(runtime) = state.portal_runtime.as_mut() else {
        tracing::warn!("portal call arrived without a running backend");
        return;
    };
    let (portal_actions, ui) = {
        let mut portal_actions = Vec::new();
        let mut ui = Vec::new();
        apply_portal_call(&mut runtime.ledger, call, &mut portal_actions, &mut ui);
        (portal_actions, ui)
    };
    for ui_event in ui {
        perform_ui_event(state, ui_event);
    }
    if let Some(runtime) = state.portal_runtime.as_mut() {
        for action in portal_actions {
            if runtime.objects.send(action).is_err() {
                tracing::warn!("portal object bridge is gone");
                return;
            }
        }
    }
}

/// Trusted shell event handling on the loop: opens and dismisses the
/// consent picker through the Flutter platform channel.
fn perform_ui_event<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    event: PortalUiEvent,
) {
    match event {
        PortalUiEvent::OpenPicker {
            session_handle,
            request_handle,
            app_name,
            consent_token,
        } => {
            let sources: Vec<serde_json::Value> = output_source_entries(state)
                .iter()
                .map(|source| {
                    json!({
                        "id": source.id,
                        "label": source.label,
                    })
                })
                .collect();
            if sources.is_empty() {
                // The world changed between Start and the picker: no
                // supported source exists, so open nothing and complete
                // the request normally.
                let reply = if let Some(runtime) = state.portal_runtime.as_mut() {
                    let mut actions = Vec::new();
                    let mut ui: Vec<PortalUiEvent> = Vec::new();
                    let matched = resolve_consent_no_picker(
                        &mut runtime.ledger,
                        &session_handle.clone(),
                        &mut actions,
                    );
                    for action in actions {
                        let _ = runtime.objects.send(action);
                    }
                    matched
                } else {
                    None
                };
                if let Some(reply) = reply {
                    reply.send(failed("no supported sources"));
                }
                tracing::warn!("consent picker opened with no sources");
                return;
            }
            state
                .flutter_engine_mut()
                .platform_method_channel
                .invoke_method(
                    "screen_cast_consent",
                    Some(Box::new(json!({
                        "sessionHandle": session_handle.as_str(),
                        "requestHandle": request_handle.as_str(),
                        "consentToken": consent_token,
                        "appName": app_name,
                        "sources": sources,
                    }))),
                    None,
                );
        }
        PortalUiEvent::DismissPicker { consent_token } => {
            state
                .flutter_engine_mut()
                .platform_method_channel
                .invoke_method(
                    "screen_cast_consent_dismissed",
                    Some(Box::new(json!({
                        "consentToken": consent_token,
                    }))),
                    None,
                );
        }
    }
}

/// Rolls a picker-less request back: no supported sources existed when
/// Start opened, so the request completes failed with no picker.
fn resolve_consent_no_picker(
    ledger: &mut PortalLedger,
    session_handle: &OwnedObjectPath,
    actions: &mut Vec<PortalAction>,
) -> Option<ReplyLink> {
    let open = ledger
        .requests
        .iter()
        .find(|(_, request)| {
            !request.cancelled
                && request.session_handle == *session_handle
                && request.consent.is_some()
        })
        .map(|(handle, _)| handle.clone())?;
    let request = ledger.requests.remove(&open)?;
    if ledger.sessions.remove(session_handle).is_some() {
        actions.push(PortalAction::CloseSession(session_handle.clone()));
    }
    request.consent.map(|consent| consent.reply)
}

/// Output source registry for this milestone: one entry per mapped
/// output. The picker names outputs, and Rust re-validates the choice
/// against this registry when consent arrives (capture specification
/// section 8.3: lifetime validation happens again after selection).
pub fn output_source_entries<BackendData: crate::backend::Backend + 'static>(
    state: &crate::state::State<BackendData>,
) -> Vec<CaptureSource> {
    state
        .space
        .outputs()
        .map(|output| CaptureSource {
            id: output.name(),
            label: output.name(),
        })
        .collect()
}

/// One shareable target the consent picker may offer.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CaptureSource {
    /// Stable identifier the picker echoes back in its decision.
    pub id: String,
    pub label: String,
}

/// Applies a frontend-owner change from Rust state (owner loss, shell loss,
/// session lock): everything authorized dies with it.
pub fn handle_frontend_owner_change<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    owner: Option<FrontendOwner>,
) {
    let (actions, ui) = {
        let Some(runtime) = state.portal_runtime.as_mut() else {
            return;
        };
        let mut actions = Vec::new();
        let mut ui = Vec::new();
        frontend_owner_changed(&mut runtime.ledger, &mut actions, &mut ui, owner);
        (actions, ui)
    };
    for ui_event in ui {
        perform_ui_event(state, ui_event);
    }
    for action in actions {
        if let Some(runtime) = state.portal_runtime.as_mut() {
            let _ = runtime.objects.send(action);
        }
    }
}

/// Applies the decision the trusted picker reports back.
///
/// The selection is validated in Rust again against the live output
/// registry (capture specification section 8.3: picker replies revalidate
/// source type, lifetime, and authorization). An approval without a
/// currently valid source behaves exactly like a cancelled flow: consent
/// for a target that vanished cannot grant anything.
pub fn handle_consent_decision<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &str,
    consent_token: u64,
    outcome: ConsentOutcome,
    source_id: Option<String>,
) {
    let approved = outcome == ConsentOutcome::Approved;
    if approved {
        let requested = source_id.as_deref();
        let valid = output_source_entries(state)
            .iter()
            .any(|source| Some(source.id.as_str()) == requested);
        if requested.is_none() || !valid {
            tracing::debug!(
                source = requested.unwrap_or("(none)"),
                "Consent approval ignored: the selected source is not shareable"
            );
        }
        // Whether the registry accepted the source or not, the producer
        // milestone turns its approval into real streams; until then both
        // outcomes complete through the same close path.
    }
    let session_handle = OwnedObjectPath::try_from(session_handle).ok();
    let Some(session_handle) = session_handle else {
        tracing::debug!("Consent decision for an unrenderable session handle");
        return;
    };
    handle_consent_through_runtime(state, &session_handle, consent_token, outcome);
}

fn handle_consent_through_runtime<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &OwnedObjectPath,
    consent_token: u64,
    outcome: ConsentOutcome,
) {
    let (actions, ui) = {
        let Some(runtime) = state.portal_runtime.as_mut() else {
            return;
        };
        let mut actions = Vec::new();
        let mut ui = Vec::new();
        if !resolve_consent(
            &mut runtime.ledger,
            session_handle,
            consent_token,
            outcome,
            &mut actions,
            &mut ui,
        ) {
            return;
        }
        (actions, ui)
    };
    for ui_event in ui {
        perform_ui_event(state, ui_event);
    }
    for action in actions {
        if let Some(runtime) = state.portal_runtime.as_mut() {
            let _ = runtime.objects.send(action);
        }
    }
}

/// What the trusted picker reports: the user approved a source, or dropped
/// the flow.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ConsentOutcome {
    Approved,
    Cancelled,
}

/// Applies a picker decision that carries a valid consent token.
///
/// Returns whether the token matched a live picker for exactly this
/// session; stale or forged tokens are left alone silently.
///
/// Approval acts as the full authorization in this milestone: the consent
/// model is real, the PipeWire producer is not. The producer milestone
/// publishes nodes and completes the Start reply with real streams; every
/// other consent path (token binding, close, revocation) matches what
/// that milestone will keep.
pub fn resolve_consent(
    ledger: &mut PortalLedger,
    session_handle: &OwnedObjectPath,
    consent_token: u64,
    outcome: ConsentOutcome,
    actions: &mut Vec<PortalAction>,
    ui: &mut Vec<PortalUiEvent>,
) -> bool {
    let matched = ledger
        .requests
        .iter()
        .find(|(_, request)| {
            !request.cancelled
                && request.session_handle == *session_handle
                && request
                    .consent
                    .as_ref()
                    .is_some_and(|consent| consent.consent_token == consent_token)
        })
        .map(|(handle, _)| handle.clone());
    let Some(handle) = matched else {
        tracing::debug!("Ignoring an unmatched or stale consent token");
        return false;
    };
    let Some(mut request) = ledger.requests.remove(&handle) else {
        return false;
    };
    let Some(consent) = request.consent.take() else {
        return false;
    };
    let reply = match outcome {
        // The producer milestone replaces this with the real stream list;
        // today there is no capture delivery to authorize a stream for,
        // and reporting success with no streams would tell the frontend
        // nothing arrived.
        ConsentOutcome::Approved => failed("capture delivery is not implemented"),
        ConsentOutcome::Cancelled => cancelled(),
    };
    consent.reply.send(reply);
    ui.push(PortalUiEvent::DismissPicker {
        consent_token: consent.consent_token,
    });

    // Consent resolved either way: nothing survives the flow in this
    // milestone, so the session closes like a rejected session.
    if ledger.sessions.remove(session_handle).is_some() {
        actions.push(PortalAction::CloseSession(session_handle.clone()));
    }
    true
}

fn unauthorized() -> PortalReply {
    tracing::warn!("Rejecting unauthenticated portal call");
    PortalReply::new(RESPONSE_FAILED, HashMap::new())
}

fn failed(message: &'static str) -> PortalReply {
    tracing::debug!(message, "Rejecting portal call");
    PortalReply::new(RESPONSE_FAILED, HashMap::new())
}

fn cancelled() -> PortalReply {
    PortalReply::new(RESPONSE_CANCELLED, HashMap::new())
}

/// The frontend-owned session path is
/// `/org/freedesktop/portal/desktop/session/<sender>/<token>`. Anything
/// else cannot be a session the backend can authorize.
fn valid_session_path(session_handle: &str) -> bool {
    session_handle.starts_with("/org/freedesktop/portal/desktop/session/")
}

/// Applies one bridged backend call: mutates the ledger, queues
/// object-level actions, and completes the awaiting zbus handler through
/// the call's own reply link.
pub fn apply_portal_call(
    ledger: &mut PortalLedger,
    call: PortalCall,
    actions: &mut Vec<PortalAction>,
    ui: &mut Vec<PortalUiEvent>,
) {
    if !caller_is_frontend(call.call_identity().as_ref(), ledger.frontend.as_ref()) {
        call.reply().send(unauthorized());
        return;
    }

    match call {
        // Created -> Configured -> Choosing -> Starting -> Active -> Closed
        PortalCall::CreateSession {
            session_handle,
            reply,
            ..
        } => {
            let response = if !valid_session_path(session_handle.as_str()) {
                failed("invalid session handle")
            } else if ledger.sessions.contains_key(&session_handle) {
                failed("session already exists")
            } else {
                tracing::info!(session_path = %session_handle, "Portal session created");
                actions.push(PortalAction::ExportSession(session_handle.clone()));
                ledger.sessions.insert(
                    session_handle,
                    PortalSession {
                        state: SessionState::Created,
                        constraints: None,
                    },
                );
                PortalReply::ok()
            };
            reply.send(response);
        }
        PortalCall::SelectSources {
            handle,
            session_handle,
            constraints,
            reply,
            ..
        } => {
            let response = match ledger.sessions.get_mut(&session_handle) {
                None => failed("unknown session"),
                Some(session) => {
                    if session.state != SessionState::Created
                        && session.state != SessionState::Configured
                    {
                        return write(reply, failed("session not in a configurable state"));
                    }
                    // SelectSources stores and validates constraints; it
                    // does not grant consent.
                    session.state = SessionState::Configured;
                    session.constraints = Some(constraints);
                    if !ledger.requests.contains_key(&handle) {
                        ledger.requests.insert(
                            handle.clone(),
                            PendingRequest {
                                session_handle,
                                cancelled: false,
                                consent: None,
                            },
                        );
                        actions.push(PortalAction::ExportRequest(handle));
                    }
                    PortalReply::ok()
                }
            };
            write(reply, response);
        }
        PortalCall::Start {
            handle,
            session_handle,
            app_id,
            constraints,
            reply,
            ..
        } => {
            if matches!(
                ledger.requests.get(&handle),
                Some(PendingRequest {
                    cancelled: true,
                    ..
                })
            ) {
                // The user closed the request: the late completion never
                // publishes a node, and no cancelled session restarts.
                ledger.requests.remove(&handle);
                actions.push(PortalAction::UnexportRequest(handle));
                return write(reply, cancelled());
            }

            // SelectSources is optional in the portal contract; Start may
            // carry the constraints itself and then opens the picker.
            if let Some(session) = ledger.sessions.get_mut(&session_handle) {
                match session.state {
                    SessionState::Created => {
                        session.state = SessionState::Configured;
                        session.constraints = Some(constraints.clone());
                    }
                    SessionState::Configured => {
                        // SelectSources already validated the constraints;
                        // Start's copy is unused.
                        session.constraints = Some(constraints.clone());
                    }
                    SessionState::Choosing | SessionState::Starting => {
                        return write(reply, failed("a picker is already open"));
                    }
                    SessionState::Closed | SessionState::Active => {
                        return write(reply, failed("session is not in a startable state"));
                    }
                }
            } else {
                tracing::warn!("unknown session");
                return write(reply, failed("unknown session"));
            }

            // Only outputs exist in this milestone: a request that cannot
            // name a monitor has no supported sources and must fail
            // normally instead of opening a picker that could approve
            // nothing.
            // (SourceTypes and its bits are validated at parse time, and
            // the default is MONITOR, so an empty intersection never
            // reaches here in practice.)
            let session = ledger
                .sessions
                .get_mut(&session_handle)
                .expect("session verified above");
            if !session
                .constraints
                .as_ref()
                .is_some_and(|c| c.types.contains(SourceTypes::MONITOR))
            {
                return write(reply, failed("no supported source types"));
            }
            session.state = SessionState::Choosing;

            // The picker now owns the Start response. The consent token is
            // minted here so a stale or replayed Flutter reply can never
            // attach to a different flow, and a reply link lives in the
            // ledger until that decision arrives.
            let consent_token = ledger.consent_token();
            let app_name = app_id;
            if !ledger.requests.contains_key(&handle) {
                actions.push(PortalAction::ExportRequest(handle.clone()));
            }
            let entry = ledger
                .requests
                .entry(handle.clone())
                .or_insert(PendingRequest {
                    session_handle: session_handle.clone(),
                    cancelled: false,
                    consent: None,
                });
            entry.consent = Some(ConsentRequest {
                consent_token,
                app_name: app_name.clone(),
                reply,
            });
            ui.push(PortalUiEvent::OpenPicker {
                session_handle,
                request_handle: handle,
                app_name,
                consent_token,
            });
        }
        PortalCall::RequestClose { handle, reply, .. } => {
            if handle.as_str().contains("/session/") {
                // A session that closes while its picker is open dismisses
                // the picker and completes the pending Start reply.
                if let Some(session) = ledger.sessions.remove(&handle) {
                    actions.push(PortalAction::CloseSession(handle.clone()));
                    close_consent_for_session(ledger, &handle, ui);
                }
                write(reply, PortalReply::ok());
            } else if let Some(request) = ledger.requests.get_mut(&handle) {
                // The request dies here for its own Start: the late reply
                // can never start a session after this flag.
                request.cancelled = true;
                cancel_consent(request, ui);
                write(reply, PortalReply::ok());
            } else {
                write(reply, failed("no such pending request"));
            }
        }
    }
}

fn write(link: ReplyLink, reply: PortalReply) {
    link.send(reply);
}

impl PortalCall {
    /// Debug visibility for the harness.
    #[cfg(test)]
    pub fn call_identity_debug(&self) -> Option<String> {
        self.call_identity().map(|caller| caller.0)
    }

    /// The sender identity is cloned out of the call: authorization must
    /// not rely on borrowed fields after destructuring.
    fn call_identity(&self) -> Option<Caller> {
        match self {
            PortalCall::CreateSession { caller, .. }
            | PortalCall::SelectSources { caller, .. }
            | PortalCall::Start { caller, .. }
            | PortalCall::RequestClose { caller, .. } => caller.clone(),
        }
    }

    fn reply(&self) -> ReplyLink {
        match self {
            PortalCall::CreateSession { reply, .. }
            | PortalCall::SelectSources { reply, .. }
            | PortalCall::Start { reply, .. }
            | PortalCall::RequestClose { reply, .. } => reply.clone(),
        }
    }
}

/// The unit tests cover pure transition correctness on the ledger: the
/// D-Bus side runs under the harness.
#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    fn ledger_with_frontend() -> (PortalLedger, PendingReply) {
        let (link, pending) = make_reply_pair();
        let ledger = PortalLedger {
            frontend: Some(FrontendOwner(":1.9".into())),
            ..Default::default()
        };
        (ledger, pending)
    }

    const SESSION_OK: &str = "/org/freedesktop/portal/desktop/session/1_9/tok1";
    const SESSION_BAD: &str = "/wrong/path";

    fn create_call(handle: &str, session: &str, reply: ReplyLink) -> PortalCall {
        PortalCall::CreateSession {
            handle: OwnedObjectPath::try_from("/org/freedesktop/portal/desktop/request/1_9/h0")
                .unwrap(),
            session_handle: OwnedObjectPath::try_from(session).unwrap(),
            app_id: "app".into(),
            caller: Some(Caller(":1.9".into())),
            reply,
        }
    }

    fn handle() -> OwnedObjectPath {
        OwnedObjectPath::try_from("/org/freedesktop/portal/desktop/request/1_9/r1").unwrap()
    }

    // The pure tests use a shared reply collector.
    #[test]
    fn create_then_repeat_fails() {
        let (mut ledger, _) = ledger_with_frontend();
        let mut actions = Vec::new();
        // Fake replies never need an actual awaiting handler here: the
        // reply link sends into a receiver that is dropped when the test
        // ends.
        drop(ledger_with_frontend().1);
        let _ = actions;

        let (link, pending) = make_reply_pair();
        let (link2, pending2) = make_reply_pair();
        apply_portal_call(
            &mut ledger,
            PortalCall::CreateSession {
                handle: OwnedObjectPath::try_from("/org/freedesktop/portal/desktop/request/1_9/h1")
                    .unwrap(),
                session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                app_id: "app".into(),
                caller: Some(Caller(":1.9".into())),
                reply: link,
            },
            &mut actions,
            &mut Vec::new(),
        );
        assert_eq!(1, actions.len(), "ExportSession queued on create");
        let applied_again = {
            let mut second = Vec::new();
            apply_portal_call(
                &mut ledger,
                PortalCall::CreateSession {
                    handle: OwnedObjectPath::try_from(
                        "/org/freedesktop/portal/desktop/request/1_9/h2",
                    )
                    .unwrap(),
                    session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                    app_id: "app".into(),
                    caller: Some(Caller(":1.9".into())),
                    reply: link2,
                },
                &mut second,
                &mut Vec::new(),
            );
            second
        };
        assert!(applied_again.is_empty());
        drop(pending);
        drop(pending2);
    }

    #[test]
    fn unauthorized_caller_gets_response_failed() {
        let (mut ledger, _pending) = ledger_with_frontend();
        let (link, pending) = make_reply_pair();
        let mut actions = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::CreateSession {
                handle: handle(),
                session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                app_id: "imposter".into(),
                caller: Some(Caller(":1.42".into())),
                reply: link,
            },
            &mut actions,
            &mut Vec::new(),
        );
        assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_FAILED);
    }

    #[test]
    fn bad_session_handle_is_rejected() {
        let (mut ledger, _guard) = ledger_with_frontend();
        let (link, pending) = make_reply_pair();
        let mut actions = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::CreateSession {
                handle: handle(),
                session_handle: OwnedObjectPath::try_from(SESSION_BAD).unwrap(),
                app_id: "app".into(),
                caller: Some(Caller(":1.9".into())),
                reply: link,
            },
            &mut actions,
            &mut Vec::new(),
        );
        let reply = pending.recv_blocking().unwrap();
        assert_eq!(reply.response, RESPONSE_FAILED);
        assert!(actions.is_empty());
    }

    #[test]
    fn select_configures_then_start_cancels_without_consent() {
        let (mut ledger, _) = ledger_with_frontend();
        let (link, _pending) = make_reply_pair();
        // create
        {
            let (link, pending) = make_reply_pair();
            let mut actions = Vec::new();
            let mut ui: Vec<PortalUiEvent> = Vec::new();
            apply_portal_call(
                &mut ledger,
                PortalCall::CreateSession {
                    handle: handle(),
                    session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                    app_id: "app".into(),
                    caller: Some(Caller(":1.9".into())),
                    reply: link,
                },
                &mut actions,
                &mut Vec::new(),
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
        }
        // configure
        let (link, pending) = make_reply_pair();
        let handle_path = handle();
        {
            let mut actions = Vec::new();
            let mut ui: Vec<PortalUiEvent> = Vec::new();
            apply_portal_call(
                &mut ledger,
                PortalCall::SelectSources {
                    handle: handle_path.clone(),
                    session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                    app_id: "app".into(),
                    constraints: super::super::ScreenCastConstraints {
                        types: super::super::SourceTypes::MONITOR,
                        cursor_mode: super::super::CursorModes::HIDDEN,
                        multiple: false,
                        restore_token: None,
                    },
                    caller: Some(Caller(":1.9".into())),
                    reply: link,
                },
                &mut actions,
                &mut Vec::new(),
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
            assert_eq!(actions.len(), 1, "request object export queued when new");
        }
        // Start: the trusted picker owns the reply; no portal response is
        // sent to the frontend yet and the session waits as Choosing.
        let (link, pending) = make_reply_pair();
        let consent_token = {
            let mut actions = Vec::new();
            let mut ui: Vec<PortalUiEvent> = Vec::new();
            apply_portal_call(
                &mut ledger,
                PortalCall::Start {
                    handle: handle_path.clone(),
                    session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                    app_id: "app".into(),
                    parent_window: "".into(),
                    constraints: super::super::ScreenCastConstraints {
                        types: super::super::SourceTypes::MONITOR,
                        cursor_mode: super::super::CursorModes::HIDDEN,
                        multiple: false,
                        restore_token: None,
                    },
                    caller: Some(Caller(":1.9".into())),
                    reply: link,
                },
                &mut actions,
                &mut ui,
            );
            assert!(
                pending.try_recv().is_err(),
                "Start must not complete until consent arrives"
            );
            assert_eq!(ui.len(), 1, "picker open queued");
            let PortalUiEvent::OpenPicker {
                consent_token,
                app_name,
                ..
            } = &ui[0]
            else {
                panic!("expected picker open");
            };
            assert_eq!(app_name, "app");
            assert_eq!(
                session_state(&ledger, SESSION_OK),
                Some(SessionState::Choosing)
            );
            *consent_token
        };

        // A forged token resolves nothing.
        {
            let mut actions = Vec::new();
            let mut ui: Vec<PortalUiEvent> = Vec::new();
            assert!(!resolve_consent(
                &mut ledger,
                &OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                consent_token + 1,
                ConsentOutcome::Approved,
                &mut actions,
                &mut ui,
            ));
            assert!(ui.is_empty());
        }

        // The matching token cancels the flow and closes the session.
        {
            let mut actions = Vec::new();
            let mut ui: Vec<PortalUiEvent> = Vec::new();
            assert!(resolve_consent(
                &mut ledger,
                &OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                consent_token,
                ConsentOutcome::Cancelled,
                &mut actions,
                &mut ui,
            ));
            assert_eq!(
                pending.recv_blocking().unwrap().response,
                RESPONSE_CANCELLED
            );
            assert_eq!(actions.len(), 1, "session close queued");
            assert!(ledger.sessions.is_empty());
            assert!(ledger.requests.is_empty());
            assert_eq!(ui.len(), 1, "picker dismissed");
        }
    }

    #[test]
    fn approval_completes_failed_until_the_producer_exists() {
        let (mut ledger, _) = ledger_with_frontend();
        let mut actions = Vec::new();
        {
            let (link, pending) = make_reply_pair();
            apply_portal_call(
                &mut ledger,
                PortalCall::CreateSession {
                    handle: handle(),
                    session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                    app_id: "app".into(),
                    caller: Some(Caller(":1.9".into())),
                    reply: link,
                },
                &mut actions,
                &mut Vec::new(),
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
        }
        // Start → picker open.
        let (link, pending) = make_reply_pair();
        let consent_token = {
            let mut ui: Vec<PortalUiEvent> = Vec::new();
            apply_portal_call(
                &mut ledger,
                PortalCall::Start {
                    handle: handle(),
                    session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                    app_id: "app".into(),
                    parent_window: "".into(),
                    constraints: super::super::ScreenCastConstraints {
                        types: super::super::SourceTypes::MONITOR,
                        cursor_mode: super::super::CursorModes::HIDDEN,
                        multiple: false,
                        restore_token: None,
                    },
                    caller: Some(Caller(":1.9".into())),
                    reply: link,
                },
                &mut actions,
                &mut ui,
            );
            let PortalUiEvent::OpenPicker { consent_token, .. } = &ui[0] else {
                panic!("expected picker open");
            };
            *consent_token
        };

        // Approval reports the producer-less flow honestly.
        let mut actions = Vec::new();
        assert!(resolve_consent(
            &mut ledger,
            &OwnedObjectPath::try_from(SESSION_OK).unwrap(),
            consent_token,
            ConsentOutcome::Approved,
            &mut actions,
            &mut Vec::new(),
        ));
        assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_FAILED);
        assert_eq!(actions.len(), 1, "session close queued");
        assert!(ledger.sessions.is_empty());
        assert!(ledger.requests.is_empty());
    }

    fn session_state(ledger: &PortalLedger, session: &str) -> Option<SessionState> {
        ledger
            .sessions
            .get(&OwnedObjectPath::try_from(session).unwrap())
            .map(|session| session.state)
    }

    #[test]
    fn frontend_loss_closes_every_session() {
        let (mut ledger, _guard) = ledger_with_frontend();
        let mut actions = Vec::new();
        {
            let (link, pending) = make_reply_pair();
            apply_portal_call(
                &mut ledger,
                PortalCall::CreateSession {
                    handle: handle(),
                    session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                    app_id: "app".into(),
                    caller: Some(Caller(":1.9".into())),
                    reply: link,
                },
                &mut actions,
                &mut Vec::new(),
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
        }

        let mut actions = Vec::new();
        frontend_owner_changed(&mut ledger, &mut actions, &mut Vec::new(), None);
        assert_eq!(actions.len(), 1, "session close queued");
        assert!(ledger.sessions.is_empty());
        assert!(ledger.frontend.is_none());

        // Calls now fail even when the frontend returns.
        let (link, pending) = make_reply_pair();
        apply_portal_call(
            &mut ledger,
            PortalCall::CreateSession {
                handle: handle(),
                session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                app_id: "app".into(),
                caller: Some(Caller(":1.9".into())),
                reply: link,
            },
            &mut actions,
            &mut Vec::new(),
        );
        assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_FAILED);
    }
}
