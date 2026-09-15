//! The portal session state machine.
//!
//! Owns no D-Bus plumbing: the lifecycle operates on a plain ledger so the
//! rules can be unit-tested without a session bus. Object-level side
//! effects are queued as [PortalAction]s for a dedicated object-bridge
//! thread; the compositor event loop never calls into zbus directly and
//! zbus handlers never touch compositor state.

use zbus::zvariant::OwnedObjectPath;

use super::{
    caller_is_frontend, make_reply_pair, Caller, PendingReply, PortalCall, PortalReply, ReplyLink,
    ScreenCastConstraints, RESPONSE_CANCELLED, RESPONSE_FAILED, RESPONSE_OK,
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
}

/// Everything the backend service must know. Every nonclosed state can
/// close, and closing never redirects to a substitute target.
#[derive(Debug, Default)]
pub struct PortalLedger {
    pub sessions: HashMap<OwnedObjectPath, PortalSession>,
    pub requests: HashMap<OwnedObjectPath, PendingRequest>,
    pub frontend: Option<FrontendOwner>,
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
                        session.constraints = Some(constraints);
                    }
                    SessionState::Configured | SessionState::Choosing | SessionState::Starting => {}
                    SessionState::Closed | SessionState::Active => {
                        return write(reply, failed("session is not in a startable state"));
                    }
                }
            } else {
                tracing::warn!("unknown session");
                return write(reply, failed("unknown session"));
            }
            let session = ledger
                .sessions
                .get_mut(&session_handle)
                .expect("session verified above");
            session.state = SessionState::Starting;
            // M2.1 placeholder: the trusted picker arrives with the consent
            // milestone; until then Start cancels safely and leaves the
            // session re-usable (there is no consent to betray).
            session.state = SessionState::Configured;
            ledger.requests.remove(&handle);
            actions.push(PortalAction::UnexportRequest(handle));
            write(reply, cancelled());
        }
        PortalCall::RequestClose { handle, reply, .. } => {
            if handle.as_str().contains("/session/") {
                if ledger.sessions.remove(&handle).is_some() {
                    actions.push(PortalAction::CloseSession(handle.clone()));
                }
                write(reply, PortalReply::ok());
            } else if let Some(request) = ledger.requests.get_mut(&handle) {
                request.cancelled = true;
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

/// A closed/replaced frontend means every pending request and session dies:
/// new consent from a new frontend instance is required before any pixel
/// flows again.
pub fn frontend_owner_changed(
    ledger: &mut PortalLedger,
    actions: &mut Vec<PortalAction>,
    owner: Option<FrontendOwner>,
) {
    let previous = ledger.frontend.as_ref().map(|current| current.0.clone());
    let next = owner.as_ref().map(|current| current.0.clone());
    let frontend_lost = owner.is_none();
    ledger.frontend = owner;
    if previous.is_some() && previous == next {
        return;
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
    let mut actions = Vec::new();
    apply_portal_call(&mut runtime.ledger, call, &mut actions);
    for action in actions {
        if runtime.objects.send(action).is_err() {
            tracing::warn!("portal object bridge is gone");
            return;
        }
    }
}

/// Applies a frontend-owner change from Rust state (owner loss, shell loss,
/// session lock): everything authorized dies with it.
pub fn handle_frontend_owner_change<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    owner: Option<FrontendOwner>,
) {
    let Some(runtime) = state.portal_runtime.as_mut() else {
        return;
    };
    let mut actions = Vec::new();
    frontend_owner_changed(&mut runtime.ledger, &mut actions, owner);
    for action in actions {
        let _ = runtime.objects.send(action);
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
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
        }
        // configure
        let (link, pending) = make_reply_pair();
        let handle_path = handle();
        {
            let mut actions = Vec::new();
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
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
            assert_eq!(actions.len(), 1, "request object export queued when new");
        }
        // Start: the consent-less placeholder cancels.
        let (link, pending) = make_reply_pair();
        {
            let mut actions = Vec::new();
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
            );
            assert_eq!(
                pending.recv_blocking().unwrap().response,
                RESPONSE_CANCELLED
            );
        }
        let session = ledger
            .sessions
            .get(&OwnedObjectPath::try_from(SESSION_OK).unwrap())
            .unwrap();
        assert_eq!(session.state, SessionState::Configured);
        assert!(ledger.requests.is_empty());
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
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
        }

        let mut actions = Vec::new();
        frontend_owner_changed(&mut ledger, &mut actions, None);
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
        );
        assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_FAILED);
    }
}
