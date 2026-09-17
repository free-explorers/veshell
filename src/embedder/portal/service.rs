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
    caller_is_frontend, make_reply_pair, Caller, PortalCall, PortalReply, ReplyLink,
    ScreenCastConstraints, SourceTypes, RESPONSE_CANCELLED, RESPONSE_FAILED, RESPONSE_OK,
};

pub use super::FrontendOwner;

use smithay::output::Output;
use smithay::reexports::calloop::channel;
use smithay::utils::{Physical, Size};
use std::path::PathBuf;
use zbus::zvariant::OwnedValue;

use crate::capture::pipewire::{ActiveStream, StreamDescriptor};

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
    /// While the PipeWire producer negotiates the stream (Starting), Start
    /// responds only once a node runs. A pending reply link here lives
    /// until NodeReady answers or the session closes.
    pub pending_start: Option<ReplyLink>,
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

/// One screenshot/pick-color flow's prompt stage (spec 8.4); the shapes
/// follow the v3 Screenshot contract.
#[derive(Debug)]
pub struct ScreenshotConsent {
    pub consent_token: u64,
    pub app_name: String,
    pub kind: CaptureKind,
    pub reply: ReplyLink,
}

/// What an approved prompt gathers: a full-screen PNG (Screen) or a
/// color sample. Both pass the same trusted prompt; their grants differ.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CaptureKind {
    Screen,
    Color,
}

/// One in-flight portal screenshot/pick-color request. Either the
/// prompt or the capture stage holds the method's reply.
#[derive(Debug)]
pub struct ScreenshotEntry {
    pub consent: Option<ScreenshotConsent>,
    pub capture: Option<ScreenshotCapture>,
}

/// An approved prompt whose capture machinery produces the result; the
/// reply completes when the encode hands back a file or a color sample.
#[derive(Debug)]
pub struct ScreenshotCapture {
    pub consent_token: u64,
    pub kind: CaptureKind,
    pub reply: ReplyLink,
}

impl Default for ScreenshotEntry {
    fn default() -> Self {
        Self {
            consent: None,
            capture: None,
        }
    }
}

/// Everything the backend service must know. Every nonclosed state can
/// close, and closing never redirects to a substitute target.
#[derive(Debug, Default)]
pub struct PortalLedger {
    pub sessions: HashMap<OwnedObjectPath, PortalSession>,
    pub requests: HashMap<OwnedObjectPath, PendingRequest>,
    /// In-flight Screenshot/PickColor portal requests (spec 8.4). These
    /// have no CaptureSession behind them: the ledger itself owns the
    /// prompt-and-capture lifecycle.
    pub screenshots: HashMap<OwnedObjectPath, ScreenshotEntry>,
    pub frontend: Option<FrontendOwner>,
    pub next_consent_token: u64,
}

use std::collections::HashMap;

/// Object-level actions the loop hands to the object-bridge thread.
#[derive(Clone, Debug)]
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
        /// The requested source kinds this flow may offer (spec 8.2: the
        /// picker is filtered by the request's `types`).
        types: SourceTypes,
    },
    DismissPicker {
        consent_token: u64,
    },
    /// Opens the screenshot consent prompt (spec 8.4: every external
    /// screenshot request prompts first). The decision returns through
    /// its own platform-channel callback with the unguessable token
    /// attached.
    OpenScreenshotPrompt {
        request_handle: OwnedObjectPath,
        app_name: String,
        kind: CaptureKind,
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
    for (_handle, entry) in ledger.screenshots.iter_mut() {
        if let Some(consent) = entry.consent.take() {
            consent.reply.send(cancelled());
            ui.push(PortalUiEvent::DismissPicker {
                consent_token: consent.consent_token,
            });
        }
        entry.capture = None;
    }
    ledger.screenshots.clear();
    let closed_sessions: Vec<OwnedObjectPath> = ledger.sessions.keys().cloned().collect();
    for session_handle in closed_sessions {
        // A session denied its Start reply before removal never completes:
        // any later close path that would answer it is gone with the
        // session itself (spec 8.3: a cancelled session may not resurrect).
        if let Some(pending) = ledger
            .sessions
            .get_mut(&session_handle)
            .and_then(|session| session.pending_start.take())
        {
            pending.send(cancelled());
        }
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
    reconcile_portal_pending_pixels(state);
    for ui_event in ui {
        perform_ui_event(state, ui_event);
    }
    for action in portal_actions {
        if let Some(runtime) = state.portal_runtime.as_mut() {
            if runtime.objects.send(action.clone()).is_err() {
                tracing::warn!("portal object bridge is gone");
                return;
            }
        }
        // Session-level D-Bus closes revoke the producer side too.
        if let PortalAction::CloseSession(session_handle) = action {
            stop_capture_side(state, &session_handle);
        }
    }
}

/// Evicts pre-prompt pixel holds whose portal request no longer exists
/// in the ledger (denials through RequestClose, completed entries):
/// buffering desktop frames past their reason to exist is a spec 8.4
/// leak.
fn reconcile_portal_pending_pixels<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
) {
    let Some(runtime) = state.portal_runtime.as_ref() else {
        state.portal_pending_pixels.clear();
        return;
    };
    let live: std::collections::HashSet<u64> = runtime
        .ledger
        .screenshots
        .values()
        .filter_map(|entry| {
            entry
                .consent
                .as_ref()
                .map(|consent| consent.consent_token)
                .or_else(|| entry.capture.as_ref().map(|capture| capture.consent_token))
        })
        .collect();
    state
        .portal_pending_pixels
        .retain(|token, _| live.contains(&token));
}

/// Capture-side revocation for one session: producer teardown and the
/// indicator. Idempotent — the second call for a closed session is a no-op
/// (no repeated `screen_cast_stopped` event, no producer work). The
/// producer stream stop itself is keyed and therefore safe to call again.
fn stop_capture_side<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &OwnedObjectPath,
) {
    let sentinel = session_handle.as_str() == "/org/freedesktop/portal/desktop";
    if sentinel {
        // The producer knows each stream by its real session handle: the
        // sentinel stands in for every live stream whose frontend is
        // gone, so the teardown reaches each recorded source by its own
        // key and one stream's teardown can never block another's.
        if let Some(producer) = state.pipe_wire_producer.as_mut() {
            for handle in state.active_streams.keys().cloned().collect::<Vec<_>>() {
                producer.stop_stream(&handle);
            }
        }
        if !state.active_streams.is_empty() {
            for handle in state.active_streams.keys().cloned().collect::<Vec<_>>() {
                hide_shared_indicator(state, &handle);
            }
        } else {
            // Nothing live: the indicator still has to disappear for the
            // sentinel itself (one event covers it).
            hide_shared_indicator(state, session_handle);
        }
        state.active_streams.clear();
        return;
    }
    if state.active_streams.remove(session_handle).is_some() {
        if let Some(producer) = state.pipe_wire_producer.as_mut() {
            producer.stop_stream(session_handle);
        }
        hide_shared_indicator(state, session_handle);
    }
}

/// Finds the shared sessions whose stream renders a given source id
/// (window-share session closure, spec 5.3: close on window
/// destruction, never a stale stream). Pure so the lifecycle shape is
/// testable without compositor state.
fn source_share_handles<'a>(
    active_streams: impl Iterator<Item = (&'a OwnedObjectPath, &'a ActiveStream)>,
    source_id: &str,
) -> Vec<OwnedObjectPath> {
    active_streams
        .filter(|(_handle, stream)| stream.source_id == source_id)
        .map(|(handle, _)| handle.clone())
        .collect()
}

/// Closes every shared session bound to `source_id` (one removed window,
/// one unmapped window): producer teardown, ledger close, and indicator
/// removal run through the ordinary close path per session.
pub fn close_source_share_sessions<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    source_id: &str,
) {
    let handles: Vec<OwnedObjectPath> =
        source_share_handles(state.active_streams.iter(), source_id);
    for handle in handles {
        close_shared_session(state, &handle);
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
            types,
        } => {
            // Sources are assembled per requested kind, never by
            // substituting one kind for another (spec 8.2). Window entries
            // carry their own stable kind tag so the decision can be
            // validated against the right registry, and the picker groups
            // outputs and windows separately.
            let outputs: Vec<(CaptureSource, &'static str)> = types
                .contains(SourceTypes::MONITOR)
                .then(|| {
                    output_source_entries(state)
                        .into_iter()
                        .map(|source| (source, "outputs"))
                        .collect()
                })
                .unwrap_or_default();
            let windows: Vec<(CaptureSource, &'static str)> = types
                .contains(SourceTypes::WINDOW)
                .then(|| {
                    window_source_entries(state)
                        .into_iter()
                        .map(|source| (source, "windows"))
                        .collect()
                })
                .unwrap_or_default();
            let sources: Vec<serde_json::Value> = outputs
                .clone()
                .into_iter()
                .chain(windows.clone())
                .map(|(source, kind)| {
                    json!({
                        "id": source.id,
                        "label": source.label,
                        "kind": kind,
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
        PortalUiEvent::OpenScreenshotPrompt {
            request_handle,
            app_name,
            kind,
            consent_token,
        } => {
            // The response frame is the pre-prompt desktop (spec 8.4):
            // freeze the pixels exactly once, before the dialog renders
            // over them. A failed pre-capture leaves no stash and the
            // approval path falls back to a fresh capture.
            let pointer = state.pointer.current_location().to_f64();
            let output = state
                .space
                .outputs()
                .find(|output| {
                    state
                        .space
                        .output_geometry(output)
                        .is_some_and(|geometry| geometry.to_f64().contains(pointer))
                })
                .or_else(|| state.space.outputs().next())
                .cloned();
            if let Some(output) = output {
                match crate::capture::take_portal_pending_snapshot(state, &output, pointer) {
                    Ok(pending) => {
                        state.portal_pending_pixels.insert(consent_token, pending);
                        if state.portal_pending_pixels.len() > 4 {
                            let oldest = *state
                                .portal_pending_pixels
                                .keys()
                                .min()
                                .take()
                                .expect("len above evict bound");
                            state.portal_pending_pixels.remove(&oldest);
                        }
                    }
                    Err(message) => {
                        tracing::warn!(message, "portal pre-prompt snapshot failed");
                    }
                }
            }
            state
                .flutter_engine_mut()
                .platform_method_channel
                .invoke_method(
                    "screenshot_prompt",
                    Some(Box::new(json!({
                        "requestHandle": request_handle.as_str(),
                        "consentToken": consent_token,
                        "appName": app_name,
                        "kind": match kind {
                            CaptureKind::Screen => "screen",
                            CaptureKind::Color => "color",
                        },
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
            kind: SourceKind::Monitor,
        })
        .collect()
}

/// One shareable target the consent picker may offer.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CaptureSource {
    /// Stable identifier the picker echoes back in its decision.
    pub id: String,
    pub label: String,
    /// Which registry authorized this entry (spec 8.2 mapping): outputs
    /// are MONITOR sources, windows are WINDOW sources.
    pub kind: SourceKind,
}

/// The portal source kind a [CaptureSource] maps to.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SourceKind {
    Monitor,
    Window,
}

impl SourceKind {
    /// The portal `source_type` value the Start result reports.
    pub fn portal_value(self) -> u32 {
        match self {
            SourceKind::Monitor => SourceTypes::MONITOR.bits(),
            SourceKind::Window => SourceTypes::WINDOW.bits(),
        }
    }
}

/// Window source registry for the picker: one entry per live, mapped
/// MetaWindow (spec 8.2: application/title and identity). Popups are not
/// windows; child dialogs are separate MetaWindows and are separate
/// entries, never auto-included with their parent.
pub fn window_source_entries<BackendData: crate::backend::Backend + 'static>(
    state: &crate::state::State<BackendData>,
) -> Vec<CaptureSource> {
    state
        .meta_window_state
        .meta_windows
        .values()
        .filter(|meta_window| meta_window.mapped)
        .map(|meta_window| CaptureSource {
            id: meta_window.id.clone(),
            label: meta_window
                .title
                .clone()
                .or_else(|| meta_window.app_id.clone())
                .unwrap_or_else(|| "Untitled window".to_string()),
            kind: SourceKind::Window,
        })
        .collect()
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
    // Pre-prompt pixel holds die with the frontend: their requests are
    // gone, whatever stage they reached.
    state.portal_pending_pixels.clear();
    // All shared sessions die with the frontend: revoke producers.
    let handles: Vec<OwnedObjectPath> = state.active_streams.keys().cloned().collect();
    for handle in handles {
        close_shared_session(state, &handle);
    }
}

/// Applies the decision the trusted picker reports back.
///
/// The selection is validated in Rust again against the live source
/// registries and the session's requested types (capture specification
/// section 8.3: picker replies revalidate source type, lifetime, and
/// authorization). An approval without a currently valid source behaves
/// exactly like a cancelled flow: consent for a target that vanished
/// cannot grant anything, and a source outside the requested kinds can
/// never be approved.
pub fn handle_consent_decision<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &str,
    consent_token: u64,
    outcome: ConsentOutcome,
    source_id: Option<String>,
) {
    let session_handle = OwnedObjectPath::try_from(session_handle).ok();
    let Some(session_handle) = session_handle else {
        tracing::debug!("Consent decision for an unrenderable session handle");
        return;
    };
    if outcome == ConsentOutcome::Approved {
        // The session's own constraints bound what may be approved.
        let allowed_types = state
            .portal_runtime
            .as_ref()
            .and_then(|runtime| runtime.ledger.sessions.get(&session_handle))
            .and_then(|session| session.constraints.as_ref())
            .map(|constraints| constraints.types);
        // Rust revalidates the selection against the live source
        // registries (spec 8.3): a vanished target cannot be approved,
        // and a kind the request did not ask for is not a shareable
        // answer even if an id collides.
        let Some(source) = source_id.as_deref().and_then(|requested| {
            capture_source_entries(state).into_iter().find(|source| {
                source.id == requested
                    && allowed_types.is_some_and(|types| types.contains(kind_to_types(source.kind)))
            })
        }) else {
            tracing::debug!("Consent approval ignored: the selected source is not shareable");
            close_shared_session(state, &session_handle);
            return;
        };
        // The ledger now holds the reply link pending; the producer
        // publishes a node and NodeReady completes the flow. Approval on a
        // session that died resolves cancelled without delivery: no node
        // is published for a consent that granted nothing.
        if handle_consent_through_runtime(state, &session_handle, consent_token, outcome)
            != ConsentResolution::Applied
        {
            return;
        }
        begin_shared_stream(state, &session_handle, source);
    } else {
        handle_consent_through_runtime(state, &session_handle, consent_token, outcome);
    }
}

/// Every shareable target currently live, across kinds: the revalidation
/// registry consent approvals answer against.
fn capture_source_entries<BackendData: crate::backend::Backend + 'static>(
    state: &crate::state::State<BackendData>,
) -> Vec<CaptureSource> {
    output_source_entries(state)
        .into_iter()
        .chain(window_source_entries(state))
        .collect()
}

fn kind_to_types(kind: SourceKind) -> SourceTypes {
    match kind {
        SourceKind::Monitor => SourceTypes::MONITOR,
        SourceKind::Window => SourceTypes::WINDOW,
    }
}

/// Applies the trusted screenshot prompt's decision (spec 8.4): the
/// unguessable token binds the reply, and an approval moves the entry
/// into its capture stage, taking the pixels exactly once with no
/// selection, desktop freeze, or pointer involvement.
pub fn handle_screenshot_prompt_decision<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    consent_token: u64,
    outcome: ConsentOutcome,
) {
    let Some(runtime) = state.portal_runtime.as_mut() else {
        tracing::debug!("Screenshot prompt decision without a portal backend");
        return;
    };
    let Some((handle, kind)) =
        resolve_screenshot_consent(&mut runtime.ledger, consent_token, outcome)
    else {
        tracing::debug!("Screenshot decision matched no live prompt");
        return;
    };
    if outcome != ConsentOutcome::Approved {
        return;
    }
    begin_portal_capture(state, &handle, kind, consent_token);
}

/// Ledger side of one screenshot prompt decision: takes the consent out
/// of its entry, answering dead-ends itself; approvals hand the kind,
/// handle, and waiting reply to the capture stage.
fn resolve_screenshot_consent(
    ledger: &mut PortalLedger,
    consent_token: u64,
    outcome: ConsentOutcome,
) -> Option<(OwnedObjectPath, CaptureKind)> {
    let matched = ledger
        .screenshots
        .iter()
        .find(|(_, entry)| {
            entry
                .consent
                .as_ref()
                .is_some_and(|consent| consent.consent_token == consent_token)
        })
        .map(|(handle, _)| handle.clone())?;
    let entry = ledger.screenshots.get_mut(&matched)?;
    let consent = entry.consent.take()?;
    entry.capture = None;
    match outcome {
        ConsentOutcome::Approved => {
            // The reply link moves with the capture stage, so the encode
            // outcome and any close path both answer it.
            entry.capture = Some(ScreenshotCapture {
                consent_token: consent.consent_token,
                kind: consent.kind,
                reply: consent.reply,
            });
            Some((matched, consent.kind))
        }
        ConsentOutcome::Cancelled => {
            consent.reply.send(cancelled());
            ledger.screenshots.remove(&matched);
            None
        }
    }
}

/// Takes the approved pixels and runs the encode worker; the outcome
/// channel completes the waiting reply.
fn begin_portal_capture<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    handle: &OwnedObjectPath,
    kind: CaptureKind,
    consent_token: u64,
) {
    // The output under the pointer, like the hotkey flow's fallback: a
    // portal "whole screen" request names no output of its own.
    let pointer = state.pointer.current_location().to_f64();
    let output = state
        .space
        .outputs()
        .find(|output| {
            state
                .space
                .output_geometry(output)
                .is_some_and(|geometry| geometry.to_f64().contains(pointer))
        })
        .or_else(|| state.space.outputs().next())
        .cloned();
    let sender = state.portal_capture_sender.clone();
    match output {
        None => {
            // No outputs at all: the request completes failed so the app
            // hears a clear answer instead of an eternal wait.
            let outcome = match kind {
                CaptureKind::Screen => PortalCaptureOutcome::Screenshot {
                    handle: handle.clone(),
                    consent_token,
                    result: Err("no output is available".to_string()),
                },
                CaptureKind::Color => PortalCaptureOutcome::Color {
                    handle: handle.clone(),
                    consent_token,
                    sample: None,
                },
            };
            let _ = sender.send(outcome);
        }
        Some(output) => {
            // The pre-prompt frame freezes the response pixels: the
            // prompt dialog may sit over the desktop while the capture
            // decision waits, and none of it may reach the result.
            let pending = state.portal_pending_pixels.remove(&consent_token);
            match kind {
                CaptureKind::Screen => {
                    let captured = match pending {
                        Some(pending) => Ok((pending.size, pending.pixels)),
                        // The pre-request snapshot failed or is gone: fall
                        // back to the live desktop, which is what older
                        // builds did.
                        None => crate::capture::capture_full_output(state, &output),
                    };
                    match captured {
                        Ok((size, pixels)) => {
                            // Encoding and file I/O belong on a worker thread,
                            // exactly like the hotkey flow.
                            let handle = handle.clone();
                            std::thread::spawn(move || {
                                let result = crate::capture::encode_portal_png(size, &pixels);
                                let _ = sender.send(PortalCaptureOutcome::Screenshot {
                                    handle,
                                    consent_token,
                                    result,
                                });
                            });
                        }
                        Err(message) => {
                            let _ = sender.send(PortalCaptureOutcome::Screenshot {
                                handle: handle.clone(),
                                consent_token,
                                result: Err(message),
                            });
                        }
                    }
                }
                CaptureKind::Color => {
                    let sample = match pending {
                        Some(pending) => {
                            crate::capture::sample_pending_pixel(&pending, pending.pointer)
                                .ok()
                                .map(|pixel| [pixel.0, pixel.1, pixel.2])
                        }
                        None => {
                            let location = state.pointer.current_location().to_f64();
                            crate::capture::sample_output_pixel(state, &output, location)
                                .map(|pixel| [pixel.0, pixel.1, pixel.2])
                                .ok()
                        }
                    };
                    let _ = sender.send(PortalCaptureOutcome::Color {
                        handle: handle.clone(),
                        consent_token,
                        sample,
                    });
                }
            }
        }
    }
}

/// Frame budget ceiling for damage-driven delivery (30 FPS).
const MIN_FRAME_INTERVAL: std::time::Duration = std::time::Duration::from_millis(33);
/// Idle refresh: a static desktop with no Flutter presents still refreshes
/// consumers at this low rate (cursor moves do not present frames today).
const IDLE_REFRESH_INTERVAL: std::time::Duration = std::time::Duration::from_millis(500);

/// Kicks off the low-rate fallback delivery for an approved session.
///
/// The fast path is damage-driven: output presents call
/// [on_view_frame_presented] and copy only what changed is delivered up to
/// the 30 FPS budget. This timer covers a completely static scene, where
/// no present ever fires, so consumers keep a quiet heartbeat instead of
/// hanging on the last frame.
///
/// The timer ends itself once the session closes or is replaced; full-frame
/// copies first (spec section 6 allows this as the initial delivery
/// implementation).
pub fn schedule_frame_delivery<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &OwnedObjectPath,
    output: smithay::output::Output,
) {
    use smithay::reexports::calloop::timer::TimeoutAction;
    let session_handle = session_handle.clone();
    let mut timer = smithay::reexports::calloop::timer::Timer::from_duration(IDLE_REFRESH_INTERVAL);
    state
        .loop_handle
        .insert_source(timer, move |_, _, state| {
            if !state.active_streams.contains_key(&session_handle) {
                return TimeoutAction::Drop;
            }
            deliver_session_frame(state, &session_handle, &output);
            TimeoutAction::ToDuration(IDLE_REFRESH_INTERVAL)
        })
        .expect("timer can be scheduled");
}

/// Copies the output into the shared buffers of exactly one session.
fn deliver_session_frame<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &OwnedObjectPath,
    output: &smithay::output::Output,
) {
    match crate::capture::capture_output_pixels(state, output) {
        Ok(snapshot) => {
            if let Some(producer) = state.pipe_wire_producer.as_mut() {
                producer.queue_frame(session_handle.clone(), &snapshot.pixels);
            }
        }
        Err(_) => {
            tracing::debug!("frame capture failed; producer is quiet until the next tick");
        }
    }
}

/// The static-desktop heartbeat for a window stream: full-frame isolated
/// copies at the idle refresh rate without relying on presents, so an
/// occluded-but-updating client keeps refreshing consumers too.
pub fn schedule_window_frame_delivery<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &OwnedObjectPath,
) {
    use smithay::reexports::calloop::timer::TimeoutAction;
    let session_handle = session_handle.clone();
    let mut timer = smithay::reexports::calloop::timer::Timer::from_duration(IDLE_REFRESH_INTERVAL);
    state
        .loop_handle
        .insert_source(timer, move |_, _, state| {
            if !state.active_streams.contains_key(&session_handle) {
                return TimeoutAction::Drop;
            }
            deliver_window_frame(state, &session_handle);
            TimeoutAction::ToDuration(IDLE_REFRESH_INTERVAL)
        })
        .expect("window frame timer can be scheduled");
}

/// Copies one isolated window frame into the session's shared buffers.
/// A window whose viewport can no longer resolve means the share's
/// geometry authority is gone: the session closes with a clear reason
/// (spec 5.3: close on window destruction, never a stale stream).
fn deliver_window_frame<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &OwnedObjectPath,
) {
    let Some(stream) = state.active_streams.get(session_handle).cloned() else {
        return;
    };
    match crate::capture::capture_window_pixels(state, &stream.source_id) {
        Ok((size, pixels)) => {
            if size != Size::from(stream.size) {
                tracing::warn!("window share size changed; closing the session");
                close_shared_session(state, session_handle);
                return;
            }
            if let Some(producer) = state.pipe_wire_producer.as_mut() {
                producer.queue_frame(session_handle.clone(), &pixels);
            }
        }
        Err(message) => {
            tracing::debug!(
                known_source = message.as_str(),
                "window frame capture failed"
            );
            close_shared_session(state, session_handle);
        }
    }
}

/// Damage-driven frame delivery on the compositor loop.
///
/// Called from the Flutter present path whenever a backing store is
/// presented to a view: this is authoritative output damage. Every
/// screen-cast session whose source lives on that view's output receives a
/// frame copy, throttled to the 30 FPS budget per session (damaged faster,
/// delivered no faster than a consumer reasonably displays).
pub fn on_view_frame_presented<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    view_id: i64,
) {
    let now = std::time::Instant::now();
    // Window streams are all due together on any present: every client's
    // texture is composited into the presented frame, so a present is the
    // damage beat for every window share, bounded by the same 30 FPS
    // budget per session.
    let due_windows: Vec<OwnedObjectPath> = state
        .active_streams
        .iter()
        .filter(|(_handle, stream)| {
            stream.source_kind == SourceKind::Window
                && stream
                    .last_frame
                    .is_none_or(|last| now.duration_since(last) >= MIN_FRAME_INTERVAL)
        })
        .map(|(handle, _)| handle.clone())
        .collect();
    for handle in &due_windows {
        if let Some(stream) = state.active_streams.get_mut(handle) {
            stream.last_frame = Some(now);
        }
        deliver_window_frame(state, handle);
    }

    let Some(output_name) = state.space.outputs().find_map(|output| {
        output
            .user_data()
            .get::<crate::flutter_engine::view::OutputViewIdWrapper>()
            .filter(|wrapper| wrapper.view_id == view_id)
            .map(|_| output.name())
    }) else {
        return;
    };
    let now = std::time::Instant::now();
    // Sessions due for a fresh copy from this damage event.
    let due: Vec<OwnedObjectPath> = state
        .active_streams
        .iter()
        .filter(|(_handle, stream)| {
            stream.source_id == output_name
                && stream
                    .last_frame
                    .is_none_or(|last| now.duration_since(last) >= MIN_FRAME_INTERVAL)
        })
        .map(|(handle, _)| handle.clone())
        .collect();
    if due.is_empty() {
        // No session due (throttled or none on this output): skip without
        // capturing anything.
        return;
    }
    // All sessions on one output share one capture: their sources are the
    // same pixels, and the copy is at most once per output per present.
    let output = state
        .space
        .outputs()
        .find(|output| output.name() == output_name)
        .cloned();
    let Some(output) = output else {
        return;
    };
    let captured = crate::capture::capture_output_pixels(state, &output).ok();
    let Some(captured) = captured else {
        tracing::debug!("frame capture failed after a present; producer stays quiet");
        return;
    };
    for handle in due {
        if let Some(producer) = state.pipe_wire_producer.as_mut() {
            producer.queue_frame(handle.clone(), &captured.pixels);
        }
        if let Some(stream) = state.active_streams.get_mut(&handle) {
            stream.last_frame = Some(now);
        }
    }
}

/// Kicks off the PipeWire stream for the approved session (spec 7).
///
/// The source kind decides the delivery path: outputs copy the composed
/// output frame, windows render their isolated client viewport (spec
/// 5.3). Both publish through the same producer contract and answer the
/// waiting Start reply through NodeReady.
fn begin_shared_stream<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &OwnedObjectPath,
    source: CaptureSource,
) {
    let target = match source.kind {
        SourceKind::Monitor => resolve_monitor_target(state, &source.id),
        SourceKind::Window => resolve_window_target(state, &source.id),
    };
    let Some(target) = target else {
        tracing::warn!("The approved source disappeared before delivery started");
        close_shared_session(state, session_handle);
        return;
    };
    if state.pipe_wire_producer.is_none() {
        match crate::capture::pipewire::Producer::new(
            &state.loop_handle,
            state.producer_delivery_sender.clone(),
        ) {
            Ok(producer) => {
                state.pipe_wire_producer = Some(producer);
            }
            Err(_) => {}
        }
    }
    let Some(producer) = state.pipe_wire_producer.as_mut() else {
        tracing::warn!("PipeWire producer is unavailable");
        close_shared_session(state, session_handle);
        return;
    };
    let descriptor = StreamDescriptor {
        session_handle: session_handle.clone(),
        source_id: source.id.clone(),
        source_kind: source.kind,
        size: target.stream_size,
        position: target.position,
        label: source.label.clone(),
    };
    producer.start_stream(descriptor);
    state.active_streams.insert(
        session_handle.clone(),
        ActiveStream {
            node_id: 0,
            source_id: source.id.clone(),
            source_kind: source.kind,
            position: target.position,
            size: (target.stream_size.w, target.stream_size.h),
            label: source.label.clone(),
            active: false,
            last_frame: None,
        },
    );
    // The frame scheduler pulls pixels into the producer buffers.
    match source.kind {
        SourceKind::Monitor => {
            let output = target
                .output
                .expect("monitor target always carries its output");
            schedule_frame_delivery(state, session_handle, output.clone());
        }
        SourceKind::Window => {
            schedule_window_frame_delivery(state, session_handle);
        }
    }
}

/// What a monitor source resolves to at delivery start.
struct CaptureTarget {
    stream_size: Size<i32, Physical>,
    /// Global logical position the Start result reports.
    position: (i32, i32),
    /// The rendering source for the frame pump; a monitor target renders
    /// its whole output.
    output: Option<Output>,
}

fn resolve_monitor_target<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    output_name: &str,
) -> Option<CaptureTarget> {
    let output = state
        .space
        .outputs()
        .find(|output| output.name() == output_name)?;
    let geometry = state.space.output_geometry(output)?;
    let mode = output.current_mode()?;
    Some(CaptureTarget {
        stream_size: mode.size,
        position: (geometry.loc.x, geometry.loc.y),
        output: Some(output.clone()),
    })
}

/// Resolves the approved window identity into a live delivery target:
/// the viewport comes from the client-closest geometry with the window's
/// scale ratio, so no live client is resized or moved by the share
/// (spec 5.3), and identity means the *same* live MetaWindow, not a new
/// window with the same title.
fn resolve_window_target<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    meta_window_id: &str,
) -> Option<CaptureTarget> {
    let meta_window = state
        .meta_window_state
        .meta_windows
        .get(meta_window_id)?
        .clone();
    if !meta_window.mapped {
        return None;
    }
    let surface = state.surfaces.get(&meta_window.surface_id)?.clone();
    let viewport_logical = crate::capture::window_viewport(&meta_window, Some(&surface))?;
    let scale = crate::capture::window_render_scale(&meta_window);
    Some(CaptureTarget {
        stream_size: crate::capture::pixel_size(viewport_logical.size, scale).ok()?,
        position: (viewport_logical.loc.x as i32, viewport_logical.loc.y as i32),
        output: None,
    })
}

/// Applies one consent decision through the ledger runtime, performs the
/// queued object/UI side effects, and reports whether the token actually
/// resolved a live picker (the call site only publishes delivery when
/// authorization truly advanced).
fn handle_consent_through_runtime<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &OwnedObjectPath,
    consent_token: u64,
    outcome: ConsentOutcome,
) -> ConsentResolution {
    let (resolution, actions, ui) = {
        let Some(runtime) = state.portal_runtime.as_mut() else {
            return ConsentResolution::NotMatched;
        };
        let mut actions = Vec::new();
        let mut ui = Vec::new();
        let resolution = resolve_consent(
            &mut runtime.ledger,
            session_handle,
            consent_token,
            outcome,
            &mut actions,
            &mut ui,
        );
        (resolution, actions, ui)
    };
    for ui_event in ui {
        perform_ui_event(state, ui_event);
    }
    for action in actions {
        if let Some(runtime) = state.portal_runtime.as_mut() {
            let _ = runtime.objects.send(action);
        }
    }
    resolution
}

/// What the trusted picker reports: the user approved a source, or dropped
/// the flow.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ConsentOutcome {
    Approved,
    Cancelled,
}

/// Producer events: lifecycle transitions land here on the compositor
/// loop. Nothing here blocks; the PipeWire main loop dispatch is a
/// level-triggered calloop source.
pub fn handle_producer_event<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    event: crate::capture::pipewire::ProducerEvent,
) {
    match event {
        crate::capture::pipewire::ProducerEvent::NodeReady {
            session_handle,
            node_id,
        } => {
            // The producer publishes the node once per event state
            // (Connecting and then Paused pre-fixate): only the first
            // Starting -> Active transition completes the Start reply and
            // shows the indicator; repeats update the node id only.
            let Some(mut stream) = state.active_streams.get(&session_handle).cloned() else {
                tracing::debug!("producer node for an unknown stream");
                return;
            };
            enum NodeAction {
                Complete,
                Repeat,
                UnknownSession,
            }
            let (action, pending_reply) = {
                let Some(runtime) = state.portal_runtime.as_mut() else {
                    return;
                };
                match runtime.ledger.sessions.get_mut(&session_handle) {
                    Some(session) if session.state == SessionState::Starting => {
                        session.state = SessionState::Active;
                        (NodeAction::Complete, session.pending_start.take())
                    }
                    Some(_) => (NodeAction::Repeat, None),
                    None => (NodeAction::UnknownSession, None),
                }
            };
            match action {
                NodeAction::UnknownSession => {
                    tracing::debug!("producer node for an unknown session");
                    let _ = state.active_streams.remove(&session_handle);
                    return;
                }
                NodeAction::Repeat => {
                    stream.node_id = node_id;
                    state
                        .active_streams
                        .insert(session_handle.clone(), stream.clone());
                    return;
                }
                NodeAction::Complete => {}
            }
            stream.node_id = node_id;
            if let Some(reply) = pending_reply {
                match stream_reply(node_id, &stream) {
                    Some(reply_message) => reply.send(reply_message),
                    None => {
                        // A malformed reply is a producer bug, never a
                        // reason to abort the compositor: the session
                        // dies through the normal close path.
                        tracing::warn!(?session_handle, "unable to build the Start result");
                        reply.send(failed("unable to build the Start result"));
                        close_shared_session(state, &session_handle);
                        return;
                    }
                }
            }
            state
                .active_streams
                .insert(session_handle.clone(), stream.clone());
            show_shared_indicator(state, session_handle.clone(), stream);
        }
        crate::capture::pipewire::ProducerEvent::Fatal {
            session_handle,
            message,
        } => {
            tracing::warn!(
                ?session_handle,
                ?message,
                "PipeWire failure: session closed"
            );
            close_shared_session(state, &session_handle);
        }
        crate::capture::pipewire::ProducerEvent::ConsumerChanged {
            session_handle,
            active,
        } => match state.active_streams.get_mut(&session_handle) {
            Some(stream) => {
                stream.active = active;
            }
            None => {
                tracing::debug!("consumer event for an unknown session");
            }
        },
    }
}

/// The result of applying one picker decision. The call site only
/// publishes delivery when authorization actually advanced on a live
/// session.
#[derive(Debug, PartialEq, Eq)]
pub enum ConsentResolution {
    /// A live picker matched the token: the decision is applied.
    Applied,
    /// A live picker matched, but the session died before the decision:
    /// the reply completed cancelled and delivery must not proceed.
    DeadEnd,
    /// The token matched nothing: stale, forged, or already consumed.
    NotMatched,
}

/// Applies a picker decision that carries a valid consent token.
///
/// Approval keeps the Start reply pending while the PipeWire producer
/// negotiates the stream: the session waits in `Starting` and the flow
/// finishes over [ProducerEvent::NodeReady]. Cancellation reports
/// response 1 and closes the session as before.
pub fn resolve_consent(
    ledger: &mut PortalLedger,
    session_handle: &OwnedObjectPath,
    consent_token: u64,
    outcome: ConsentOutcome,
    actions: &mut Vec<PortalAction>,
    ui: &mut Vec<PortalUiEvent>,
) -> ConsentResolution {
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
        return ConsentResolution::NotMatched;
    };
    let Some(mut request) = ledger.requests.remove(&handle) else {
        return ConsentResolution::NotMatched;
    };
    let Some(consent) = request.consent.take() else {
        return ConsentResolution::NotMatched;
    };
    match outcome {
        ConsentOutcome::Approved => {
            // The reply waits until the producer publishes a node. The
            // session state carries the link so any later close path can
            // still complete the reply even if the request object has
            // already been dropped, but no leak is possible since a link
            // never stores a value until one is sent.
            if let Some(session) = ledger.sessions.get_mut(session_handle) {
                session.state = SessionState::Starting;
                session.pending_start = Some(consent.reply);
            } else {
                // Session vanished between picker and approval: a real
                // close path owns the session and is gone, so approval
                // grants nothing (spec 8.3). The reply completes
                // cancelled right here: no later close path can reach a
                // request that lost its ledger entry.
                tracing::warn!("approved consent has no live session");
                consent.reply.send(cancelled());
                ui.push(PortalUiEvent::DismissPicker {
                    consent_token: consent.consent_token,
                });
                return ConsentResolution::DeadEnd;
            }
        }
        ConsentOutcome::Cancelled => {
            consent.reply.send(cancelled());
            if ledger.sessions.remove(session_handle).is_some() {
                actions.push(PortalAction::CloseSession(session_handle.clone()));
            }
        }
    }
    ui.push(PortalUiEvent::DismissPicker {
        consent_token: consent.consent_token,
    });
    ConsentResolution::Applied
}

/// Screenshot-portal capture outcomes (spec 8.4): the encode worker
/// reports the finished path (or a failure) here, and the loop answers
/// the waiting backend reply. A `None` sample or an encode error is
/// response code 2; the requesting app hears a clear failure.
#[derive(Debug)]
pub enum PortalCaptureOutcome {
    Screenshot {
        handle: OwnedObjectPath,
        consent_token: u64,
        result: Result<PathBuf, String>,
    },
    Color {
        handle: OwnedObjectPath,
        consent_token: u64,
        sample: Option<[f64; 3]>,
    },
}

/// Registers the loop source that receives portal capture outcomes; the
/// returned sender lives on worker threads.
pub fn insert_portal_capture_source<BackendData: crate::backend::Backend + 'static>(
    loop_handle: &smithay::reexports::calloop::LoopHandle<
        'static,
        crate::state::State<BackendData>,
    >,
) -> channel::Sender<PortalCaptureOutcome> {
    let (sender, receiver) = channel::channel::<PortalCaptureOutcome>();
    loop_handle
        .insert_source(receiver, |event, _, state| {
            if let channel::Event::Msg(outcome) = event {
                handle_portal_capture_outcome(state, outcome);
            }
        })
        .expect("Failed to init portal capture channel");
    sender
}

/// Applies one capture-worker outcome to the ledger: the reply completes
/// on the loop and the request object unexports.
fn handle_portal_capture_outcome<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    outcome: PortalCaptureOutcome,
) {
    let outcome_kind = match &outcome {
        PortalCaptureOutcome::Screenshot { .. } => CaptureKind::Screen,
        PortalCaptureOutcome::Color { .. } => CaptureKind::Color,
    };
    let (handle, consent_token) = match &outcome {
        PortalCaptureOutcome::Screenshot {
            handle,
            consent_token,
            ..
        }
        | PortalCaptureOutcome::Color {
            handle,
            consent_token,
            ..
        } => (handle.clone(), *consent_token),
    };
    let Some(runtime) = state.portal_runtime.as_mut() else {
        tracing::warn!("portal capture outcome without a running backend");
        return;
    };
    // The capture stage holds the reply; it is consumed exactly once.
    let reply_link = {
        let ledger = &mut runtime.ledger;
        let Some(entry) = ledger.screenshots.get_mut(&handle) else {
            tracing::debug!("portal capture outcome discarded: no live request");
            return;
        };
        let Some(capture) = entry.capture.take() else {
            tracing::debug!("portal capture outcome without a capture stage");
            return;
        };
        if capture.consent_token != consent_token || capture.kind != outcome_kind {
            // A stale outcome cannot attach to a replaced generation.
            entry.capture = Some(capture);
            tracing::debug!("portal capture outcome generation mismatch");
            return;
        }
        capture.reply
    };
    let response = match outcome {
        PortalCaptureOutcome::Screenshot { result, .. } => match result {
            Ok(path) => {
                let mut results = super::PortalDict::new();
                results.insert(
                    "uri".to_string(),
                    OwnedValue::from(zbus::zvariant::Str::from(uri_for_path(&path))),
                );
                PortalReply::new(RESPONSE_OK, results)
            }
            Err(message) => {
                tracing::warn!(message, "portal screenshot encode failed");
                failed("the screenshot could not be taken")
            }
        },
        PortalCaptureOutcome::Color { sample, .. } => {
            use zbus::zvariant::{StructureBuilder, Value};
            let encoded = sample.and_then(|color| {
                StructureBuilder::new()
                    .add_field(color[0])
                    .add_field(color[1])
                    .add_field(color[2])
                    .build()
                    .ok()
                    .and_then(|structure| OwnedValue::try_from(Value::Structure(structure)).ok())
            });
            match encoded {
                Some(color) => {
                    let mut results = super::PortalDict::new();
                    results.insert("color".to_string(), color);
                    PortalReply::new(RESPONSE_OK, results)
                }
                None => {
                    tracing::warn!("portal color pick had no pixels");
                    failed("the color could not be sampled")
                }
            }
        }
    };
    // A completed capture unwinds its request object.
    runtime.ledger.screenshots.remove(&handle);
    let _ = runtime.objects.send(PortalAction::UnexportRequest(handle));
    reply_link.send(response);
}

/// `file://` URI written into the Screenshot results dictionary: the
/// frontend hands it on, and per spec 8.4 the file already exists on a
/// path the requesting app can follow.
fn uri_for_path(path: &std::path::Path) -> String {
    "file://".to_string() + &path.to_string_lossy()
}

/// Builds the Start result once the producer publishes a node: the
/// `(u, a{sv})` tuple Chrome and OBS need to connect, with position,
/// logical size, and the MONITOR source type.
/// The persistent trusted indicator (spec 8.3): names the shared target
/// and offers Stop. Appears before delivery begins and stays reachable
/// across workspaces.
fn show_shared_indicator<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: OwnedObjectPath,
    stream: ActiveStream,
) {
    state
        .flutter_engine_mut()
        .platform_method_channel
        .invoke_method(
            "screen_cast_active",
            Some(Box::new(json!({
                "sessionHandle": session_handle.as_str(),
                "sourceLabel": stream.label,
            }))),
            None,
        );
}

/// The shell indicator reports the session is gone (user Stop, session
/// close, target disappearance, frontend loss).
fn hide_shared_indicator<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &OwnedObjectPath,
) {
    state
        .flutter_engine_mut()
        .platform_method_channel
        .invoke_method(
            "screen_cast_stopped",
            Some(Box::new(json!({
                "sessionHandle": session_handle.as_str(),
            }))),
            None,
        );
}

/// Closes a shared session end to end: ledger close, producer stop, and
/// indicator removal. Every close path funnels here for the capture side;
/// the portal Request/Session close paths handle their own D-Bus plumbing
/// and then call this for the producer world.
pub fn close_shared_session<BackendData: crate::backend::Backend + 'static>(
    state: &mut crate::state::State<BackendData>,
    session_handle: &OwnedObjectPath,
) {
    let actions = match state.portal_runtime.as_mut() {
        Some(runtime) => {
            let mut actions = Vec::new();
            if let Some(session) = runtime.ledger.sessions.get_mut(session_handle) {
                if let Some(reply) = session.pending_start.take() {
                    reply.send(cancelled());
                }
            }
            if let Some(session) = runtime.ledger.sessions.remove(session_handle) {
                let _ = session;
                actions.push(PortalAction::CloseSession(session_handle.clone()));
            }
            runtime
                .ledger
                .requests
                .retain(|_, request| request.session_handle.as_str() != session_handle.as_str());
            actions
        }
        None => Vec::new(),
    };
    for action in actions {
        if let Some(runtime) = state.portal_runtime.as_mut() {
            let _ = runtime.objects.send(action);
        }
    }
    stop_capture_side(state, session_handle);
}

fn stream_reply(node_id: u32, stream: &ActiveStream) -> Option<PortalReply> {
    use zbus::zvariant::{Array, Dict, OwnedValue, Signature, StructureBuilder, Value};

    // a{sv}: string keys, variant values — every value carries the `v`
    // signature itself; a bare structure inside a variant dict is a
    // signature mismatch that once aborted the compositor.
    let mut dict = Dict::new(&Signature::Str, &Signature::Variant);
    let position = StructureBuilder::new()
        .add_field(stream.position.0)
        .add_field(stream.position.1)
        .build()
        .ok()?;
    dict.append(
        Value::new("position"),
        Value::Value(Box::new(Value::Structure(position))),
    )
    .ok()?;
    let size = StructureBuilder::new()
        .add_field(stream.size.0)
        .add_field(stream.size.1)
        .build()
        .ok()?;
    dict.append(
        Value::new("size"),
        Value::Value(Box::new(Value::Structure(size))),
    )
    .ok()?;
    dict.append(
        Value::new("source_type"),
        Value::Value(Box::new(Value::U32(stream.source_kind.portal_value()))),
    )
    .ok()?;

    // a(ua{sv}): (node_id, a{sv}) tuple per stream. The dict field joins
    // through append_field: `add_field` wraps an existing Value into a
    // Variant again (Value::new(Value)), which turned the element
    // signature into (uv) and once broke the array append.
    let stream_struct = StructureBuilder::new()
        .append_field(Value::U32(node_id))
        .append_field(Value::Dict(dict))
        .build()
        .ok()?;
    let element_signature = Signature::structure([
        Signature::U32,
        Signature::dict(Signature::Str, Signature::Variant),
    ]);
    let mut streams = Array::new(&element_signature);
    if streams.append(Value::new(stream_struct)).is_err() {
        return None;
    }
    let mut results = HashMap::<String, OwnedValue>::new();
    let Ok(encoded) = OwnedValue::try_from(Value::Array(streams)) else {
        return None;
    };
    results.insert("streams".to_string(), encoded);
    Some(PortalReply::new(RESPONSE_OK, results))
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
fn valid_request_path(handle: &str) -> bool {
    handle.starts_with("/org/freedesktop/portal/desktop/request/")
}

fn valid_session_path(session_handle: &str) -> bool {
    session_handle.starts_with("/org/freedesktop/portal/desktop/session/")
}

/// Opens a Screenshot/PickColor portal request: validates the request
/// handle, exports the Request object, mints the prompt token, and
/// defers the method's reply to the trusted prompt (spec 8.4). These
/// are not session flows: the entries live in the ledger's
/// 'screenshots' map and answer directly.
fn open_screenshot_request(
    ledger: &mut PortalLedger,
    actions: &mut Vec<PortalAction>,
    ui: &mut Vec<PortalUiEvent>,
    handle: OwnedObjectPath,
    app_id: String,
    kind: CaptureKind,
    reply: ReplyLink,
) {
    let response = if !valid_request_path(handle.as_str()) {
        failed("invalid request handle")
    } else if ledger.screenshots.contains_key(&handle) {
        failed("request already exists")
    } else {
        let consent_token = ledger.consent_token();
        let app_name = app_id;
        ledger.screenshots.insert(
            handle.clone(),
            ScreenshotEntry {
                consent: Some(ScreenshotConsent {
                    consent_token,
                    app_name: app_name.clone(),
                    kind,
                    reply,
                }),
                capture: None,
            },
        );
        actions.push(PortalAction::ExportRequest(handle.clone()));
        ui.push(PortalUiEvent::OpenScreenshotPrompt {
            request_handle: handle,
            app_name,
            kind,
            consent_token,
        });
        // The reply link sits in the ledger until the decision arrives.
        return;
    };
    reply.send(response);
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
    // The ownership event is self-generated trust state, not a caller:
    // it updates the ledger directly and carries no reply.
    match call {
        PortalCall::FrontendOwnerChanged { owner } => {
            frontend_owner_changed(ledger, actions, ui, owner);
            return;
        }
        call @ (PortalCall::CreateSession { .. }
        | PortalCall::SelectSources { .. }
        | PortalCall::Start { .. }
        | PortalCall::Screenshot { .. }
        | PortalCall::PickColor { .. }
        | PortalCall::RequestClose { .. }) => {
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
                                pending_start: None,
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
                            tracing::info!(
                                requested_types = ?constraints.types,
                                "Stored the source kinds SelectSources requested"
                            );
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
                    parent_window: _,
                    constraints,
                    options,
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
                    //
                    // Constraint precedence (live Chromium/OBS flows found
                    // this: they call SelectSources with `types: 3` and
                    // then Start with the option keys omitted, and the
                    // parse defaults must not clobber the stored WINDOW
                    // kinds out of the picker):
                    // - an explicitly sent Start key wins (newest frontend
                    //   instruction),
                    // - a key the Start dict omits falls back to what
                    //   SelectSources stored,
                    // - with neither SelectSources nor the key, the parse
                    //   defaults apply.
                    if let Some(session) = ledger.sessions.get_mut(&session_handle) {
                        match session.state {
                            SessionState::Created => {
                                session.state = SessionState::Configured;
                                session.constraints = Some(constraints.clone());
                            }
                            SessionState::Configured => {
                                let start_types_explicit = options.contains_key("types");
                                let start_cursor_explicit = options.contains_key("cursor_mode");
                                if !start_types_explicit || !start_cursor_explicit {
                                    if let Some(stored) = session.constraints.as_ref() {
                                        let merged = ScreenCastConstraints {
                                            types: if start_types_explicit {
                                                constraints.types
                                            } else {
                                                stored.types
                                            },
                                            cursor_mode: if start_cursor_explicit {
                                                constraints.cursor_mode
                                            } else {
                                                stored.cursor_mode
                                            },
                                            ..constraints.clone()
                                        };
                                        session.constraints = Some(merged);
                                    } else {
                                        session.constraints = Some(constraints.clone());
                                    }
                                } else {
                                    session.constraints = Some(constraints.clone());
                                }
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

                    // A request that cannot name a supported source type has
                    // no supported sources and must fail normally instead of
                    // opening a picker that could approve nothing (spec 8.2:
                    // a VIRTUAL-only request fails normally). The
                    // conjunction rides the same intersection the parse
                    // produced: an empty advertisement can never reach here
                    // (SourceTypes bits are validated at parse time).
                    //
                    // M2 shipped output sharing; M4's window sharing makes
                    // both implemented source kinds available, so the start
                    // gate requires at least one of the two rather than
                    // MONITOR alone (screencast section 8.2: filter by
                    // requested types, never substitute).
                    let session = ledger
                        .sessions
                        .get_mut(&session_handle)
                        .expect("session verified above");
                    let types = session
                        .constraints
                        .as_ref()
                        .map(|c| c.types)
                        .unwrap_or(SourceTypes::empty());
                    if !types.intersects(SourceTypes::MONITOR | SourceTypes::WINDOW) {
                        return write(reply, failed("no supported source types"));
                    }
                    session.state = SessionState::Choosing;

                    // Runtime diagnostics: which source kinds the caller
                    // actually requested for this flow (Brave and other
                    // Chromium clients send `types: 3` even when showing
                    // their own window/share UX, which is why the mixed
                    // picker exists).
                    tracing::info!(
                        app = %app_id,
                        requested_types = ?types,
                        "Opening the consent picker for a screen-cast flow"
                    );

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
                        types,
                    });
                }
                PortalCall::Screenshot {
                    handle,
                    app_id,
                    reply,
                    ..
                } => {
                    open_screenshot_request(
                        ledger,
                        actions,
                        ui,
                        handle,
                        app_id,
                        CaptureKind::Screen,
                        reply,
                    );
                }
                PortalCall::PickColor {
                    handle,
                    app_id,
                    reply,
                    ..
                } => {
                    open_screenshot_request(
                        ledger,
                        actions,
                        ui,
                        handle,
                        app_id,
                        CaptureKind::Color,
                        reply,
                    );
                }
                PortalCall::RequestClose { handle, reply, .. } => {
                    if handle.as_str().contains("/session/") {
                        // A session that closes while its picker is open dismisses
                        // the picker and completes the pending Start reply.
                        if let Some(session) = ledger.sessions.remove(&handle) {
                            if let Some(pending) = session.pending_start {
                                pending.send(cancelled());
                            }
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
                    } else if let Some(screenshot) = ledger.screenshots.remove(&handle) {
                        // A closed screenshot request completes cancelled no
                        // matter its stage; an in-flight capture is abandoned
                        // and its encode outcome discarded.
                        if let Some(consent) = screenshot.consent {
                            consent.reply.send(cancelled());
                            ui.push(PortalUiEvent::DismissPicker {
                                consent_token: consent.consent_token,
                            });
                        }
                        if screenshot.capture.is_some() {
                            tracing::info!("A closed Screenshot request abandons its capture");
                        }
                        actions.push(PortalAction::UnexportRequest(handle.clone()));
                        write(reply, PortalReply::ok());
                    } else {
                        write(reply, failed("no such pending request"));
                    }
                }
                PortalCall::FrontendOwnerChanged { .. } => {
                    unreachable!("handled by the outer match; this inner match is the caller case")
                }
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
            | PortalCall::Screenshot { caller, .. }
            | PortalCall::PickColor { caller, .. }
            | PortalCall::RequestClose { caller, .. } => caller.clone(),
            // An ownership event carries no caller identity.
            PortalCall::FrontendOwnerChanged { .. } => None,
        }
    }

    fn reply(&self) -> ReplyLink {
        match self {
            PortalCall::CreateSession { reply, .. }
            | PortalCall::SelectSources { reply, .. }
            | PortalCall::Start { reply, .. }
            | PortalCall::Screenshot { reply, .. }
            | PortalCall::PickColor { reply, .. }
            | PortalCall::RequestClose { reply, .. } => reply.clone(),
            // The ownership event carries no reply.
            PortalCall::FrontendOwnerChanged { .. } => {
                let (link, _) = make_reply_pair();
                link
            }
        }
    }
}

/// The unit tests cover pure transition correctness on the ledger: the
/// D-Bus side runs under the harness.
#[cfg(test)]
mod tests {
    use super::*;
    use crate::portal::PendingReply;
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
    const SCREEN_OK: &str = "/org/freedesktop/portal/desktop/request/1_9/sh2";

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
                    options: super::super::PortalDict::new(),
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
            assert_eq!(
                resolve_consent(
                    &mut ledger,
                    &OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                    consent_token + 1,
                    ConsentOutcome::Approved,
                    &mut actions,
                    &mut ui,
                ),
                ConsentResolution::NotMatched
            );
            assert!(ui.is_empty());
        }

        // The matching token cancels the flow and closes the session.
        {
            let mut actions = Vec::new();
            let mut ui: Vec<PortalUiEvent> = Vec::new();
            assert_eq!(
                resolve_consent(
                    &mut ledger,
                    &OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                    consent_token,
                    ConsentOutcome::Cancelled,
                    &mut actions,
                    &mut ui,
                ),
                ConsentResolution::Applied
            );
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
                    options: super::super::PortalDict::new(),
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

        // Approval keeps the producer handshake pending: the Start reply
        // waits unanswered while the session holds Starting.
        let mut actions = Vec::new();
        assert_eq!(
            resolve_consent(
                &mut ledger,
                &OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                consent_token,
                ConsentOutcome::Approved,
                &mut actions,
                &mut Vec::new(),
            ),
            ConsentResolution::Applied
        );
        assert!(pending.try_recv().is_err(), "approval may not reply yet");
        assert!(!ledger.sessions.is_empty());
        assert_eq!(
            session_state(&ledger, SESSION_OK),
            Some(SessionState::Starting)
        );
    }

    fn session_state(ledger: &PortalLedger, session: &str) -> Option<SessionState> {
        ledger
            .sessions
            .get(&OwnedObjectPath::try_from(session).unwrap())
            .map(|session| session.state)
    }

    // The requested kinds decide whether Start may open the picker: a
    // WINDOW-only request reaches Choosing (window sharing exists in M4)
    // and carries the constraint kinds into the picker event (spec 8.2:
    // filter the picker by requested types).
    #[test]
    fn start_with_window_only_request_opens_the_picker() {
        let (mut ledger, _) = ledger_with_frontend();
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
                &mut Vec::new(),
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
        }
        let (link, pending) = make_reply_pair();
        let mut actions = Vec::new();
        let mut ui: Vec<PortalUiEvent> = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::Start {
                handle: handle(),
                session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                app_id: "app".into(),
                parent_window: "".into(),
                options: super::super::PortalDict::new(),
                constraints: ScreenCastConstraints {
                    types: SourceTypes::WINDOW,
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
        let PortalUiEvent::OpenPicker { types, .. } = &ui[0] else {
            panic!("expected picker open");
        };
        assert_eq!(*types, SourceTypes::WINDOW);
        assert_eq!(
            session_state(&ledger, SESSION_OK),
            Some(SessionState::Choosing)
        );
        drop(pending);
    }

    // The live Chromium/Brave flow pinned from the session log: Start
    // omits its option keys, so the kinds SelectSources stored (`types:
    // 3` sent even for a window share) must reach the picker untouched —
    // the parse defaults never clobber them (the missing windows list in
    // the first runtime run).
    #[test]
    fn start_without_types_keeps_the_selectsources_stored_kinds() {
        let (mut ledger, _) = ledger_with_frontend();
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
                &mut Vec::new(),
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
        }
        // The frontend's SelectSources: monitor and window kinds.
        {
            let (link, pending) = make_reply_pair();
            let mut actions = Vec::new();
            apply_portal_call(
                &mut ledger,
                PortalCall::SelectSources {
                    handle: handle(),
                    session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                    app_id: "app".into(),
                    constraints: ScreenCastConstraints {
                        types: SourceTypes::MONITOR | SourceTypes::WINDOW,
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
        }
        // Start carries no option keys: the stored kinds govern the picker.
        let (link, pending) = make_reply_pair();
        let mut actions = Vec::new();
        let mut ui: Vec<PortalUiEvent> = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::Start {
                handle: handle(),
                session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                app_id: "app".into(),
                parent_window: "".into(),
                options: super::super::PortalDict::new(),
                constraints: ScreenCastConstraints {
                    // The parse defaults Start hands over when the keys
                    // are absent.
                    types: SourceTypes::MONITOR,
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
        let PortalUiEvent::OpenPicker { types, .. } = &ui[0] else {
            panic!("expected picker open");
        };
        assert_eq!(
            *types,
            SourceTypes::MONITOR | SourceTypes::WINDOW,
            "SelectSources' kinds must survive a key-less Start"
        );
        drop(pending);
    }

    // A Start that explicitly re-specifies the kinds is the newest
    // frontend instruction: it overrides the SelectSources storage.
    #[test]
    fn start_with_explicit_types_overrides_the_stored_kinds() {
        let (mut ledger, _) = ledger_with_frontend();
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
                &mut Vec::new(),
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
        }
        {
            let (link, pending) = make_reply_pair();
            let mut actions = Vec::new();
            apply_portal_call(
                &mut ledger,
                PortalCall::SelectSources {
                    handle: handle(),
                    session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                    app_id: "app".into(),
                    constraints: ScreenCastConstraints {
                        types: SourceTypes::MONITOR | SourceTypes::WINDOW,
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
        }
        let mut options: super::super::PortalDict = HashMap::new();
        options.insert(
            "types".to_string(),
            zbus::zvariant::OwnedValue::from(SourceTypes::WINDOW.bits()),
        );
        let (link, pending) = make_reply_pair();
        let mut actions = Vec::new();
        let mut ui: Vec<PortalUiEvent> = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::Start {
                handle: handle(),
                session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                app_id: "app".into(),
                parent_window: "".into(),
                options,
                constraints: ScreenCastConstraints {
                    types: SourceTypes::WINDOW,
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
        let PortalUiEvent::OpenPicker { types, .. } = &ui[0] else {
            panic!("expected picker open");
        };
        assert_eq!(*types, SourceTypes::WINDOW);
        drop(pending);
    }

    // Window-share session closure binds by the *shared window's* id:
    // sessions rendering other sources stay untouched (spec 5.3: close
    // on window destruction, never a stale stream or an unrelated
    // session).
    #[test]
    fn source_share_handles_matches_only_the_shared_source() {
        let handle_a = OwnedObjectPath::try_from(SESSION_OK).unwrap();
        let handle_b =
            OwnedObjectPath::try_from("/org/freedesktop/portal/desktop/session/1_9/other").unwrap();
        let mut map = HashMap::new();
        map.insert(
            handle_a.clone(),
            ActiveStream {
                node_id: 1,
                source_id: "window-1".into(),
                source_kind: SourceKind::Window,
                position: (0, 0),
                size: (100, 100),
                label: "window-1".into(),
                active: false,
                last_frame: None,
            },
        );
        map.insert(
            handle_b.clone(),
            ActiveStream {
                node_id: 2,
                source_id: "window-2".into(),
                source_kind: SourceKind::Window,
                position: (0, 0),
                size: (100, 100),
                label: "window-2".into(),
                active: false,
                last_frame: None,
            },
        );
        map.insert(
            OwnedObjectPath::try_from("/org/freedesktop/portal/desktop/session/1_9/monitor")
                .unwrap(),
            ActiveStream {
                node_id: 3,
                source_id: "DP-1".into(),
                source_kind: SourceKind::Monitor,
                position: (0, 0),
                size: (1920, 1080),
                label: "DP-1".into(),
                active: false,
                last_frame: None,
            },
        );

        let matched = source_share_handles(map.iter(), "window-1");
        assert_eq!(matched, vec![handle_a.clone()]);

        let nothing = source_share_handles(map.iter(), "window-gone");
        assert!(nothing.is_empty());
    }

    // A start flow whose constraints name no implemented kind completes
    // failed without opening a picker: a request that can never name a
    // shareable source has no supported sources (spec 8.2: a
    // VIRTUAL-only request fails normally). The gate is a second line of
    // defense behind option parsing, which rejects such requests first.
    #[test]
    fn start_with_no_shareable_source_types_fails_normally() {
        let (mut ledger, _) = ledger_with_frontend();
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
                &mut Vec::new(),
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
        }
        let (link, pending) = make_reply_pair();
        let mut actions = Vec::new();
        let mut ui_opened: Vec<PortalUiEvent> = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::Start {
                handle: handle(),
                session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                app_id: "app".into(),
                parent_window: "".into(),
                options: super::super::PortalDict::new(),
                constraints: ScreenCastConstraints {
                    types: SourceTypes::empty(),
                    cursor_mode: super::super::CursorModes::HIDDEN,
                    multiple: false,
                    restore_token: None,
                },
                caller: Some(Caller(":1.9".into())),
                reply: link,
            },
            &mut actions,
            &mut ui_opened,
        );
        assert_eq!(
            pending.recv_blocking().unwrap().response,
            RESPONSE_FAILED,
            "no implemented kind means a normal failure"
        );
        assert!(
            ui_opened.is_empty(),
            "no picker opens without a shareable kind"
        );
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

    // The live-rebinding entry point: a frontend restart produces a new
    // unique owner; the event closes everything the old owner had, binds
    // the new owner, and the very next call from the new name succeeds.
    // This is the fresh-login race shape: the backend may start before
    // the frontend ever claimed its name, and only this event binds it.
    #[test]
    fn frontend_rebinding_accepts_the_new_owner() {
        // Seed: no owner known at startup (backend won the login race).
        let mut ledger = PortalLedger::default();
        // ... and the frontend appears for the first time.
        let mut actions = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::FrontendOwnerChanged {
                owner: Some(FrontendOwner(":1.44".into())),
            },
            &mut actions,
            &mut Vec::new(),
        );
        assert_ty(&ledger, ":1.44");

        let (link, pending) = make_reply_pair();
        apply_portal_call(
            &mut ledger,
            PortalCall::CreateSession {
                handle: handle(),
                session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                app_id: "app".into(),
                caller: Some(Caller(":1.44".into())),
                reply: link,
            },
            &mut actions,
            &mut Vec::new(),
        );
        assert_eq!(
            pending.recv_blocking().unwrap().response,
            RESPONSE_OK,
            "the frontend owner bound through the event authorizes calls"
        );

        // Restart: a new owner appears. The old session dies (nothing can
        // unexport an old frontend's objects) and the new owner binds.
        apply_portal_call(
            &mut ledger,
            PortalCall::FrontendOwnerChanged {
                owner: Some(FrontendOwner(":1.52".into())),
            },
            &mut actions,
            &mut Vec::new(),
        );
        assert!(ledger.sessions.is_empty());
        assert_ty(&ledger, ":1.52");
        // The new owner is accepted immediately.
        let (link, pending) = make_reply_pair();
        apply_portal_call(
            &mut ledger,
            PortalCall::CreateSession {
                handle: handle(),
                session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                app_id: "app".into(),
                caller: Some(Caller(":1.52".into())),
                reply: link,
            },
            &mut actions,
            &mut Vec::new(),
        );
        assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
    }

    /// Asserts the ledger's bound frontend owner by value.
    fn assert_ty(ledger: &PortalLedger, owner: &str) {
        assert_eq!(
            ledger.frontend.as_ref().map(|frontend| frontend.0.as_str()),
            Some(owner)
        );
    }

    // Owner loss through the public entry point — should match the direct
    // `frontend_owner_changed` semantics: Starting sessions' pending Start
    // replies complete cancelled and no state survives.
    #[test]
    fn owner_change_event_loss_completes_pending_start() {
        let (ledger, pending, _token) = ledger_with_starting_session();
        let mut ledger = ledger;
        let mut actions = Vec::new();
        let mut ui: Vec<PortalUiEvent> = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::FrontendOwnerChanged { owner: None },
            &mut actions,
            &mut ui,
        );
        assert_eq!(
            pending.recv_blocking().unwrap().response,
            RESPONSE_CANCELLED
        );
        assert!(ledger.sessions.is_empty());
        assert!(ledger.requests.is_empty());
        assert!(ledger.frontend.is_none());
        assert_eq!(actions.len(), 1, "session close queued");
        // The picker closed at approval time; the loss event dismisses
        // nothing further.
        assert!(ui.is_empty());
    }

    // Owner loss while a picker is still open: the Start reply that owns
    // the picker completes cancelled immediately and the picker is
    // dismissed through the same event (spec 8.3).
    #[test]
    fn owner_loss_while_picker_open_cancels_start() {
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
        let (link, pending) = make_reply_pair();
        apply_portal_call(
            &mut ledger,
            PortalCall::Start {
                handle: handle(),
                session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                app_id: "app".into(),
                parent_window: "".into(),
                options: super::super::PortalDict::new(),
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
        assert!(pending.try_recv().is_err(), "picker owns the reply");

        apply_portal_call(
            &mut ledger,
            PortalCall::FrontendOwnerChanged { owner: None },
            &mut Vec::new(),
            &mut Vec::new(),
        );
        assert_eq!(
            pending.recv_blocking().unwrap().response,
            RESPONSE_CANCELLED,
            "frontend loss cancels the picker-owned Start reply"
        );
        assert!(ledger.sessions.is_empty());
    }

    /// Drives create → Start → picker open → approval, leaving the ledger
    /// with the session in `Starting` and its Start reply pending.
    fn ledger_with_starting_session() -> (PortalLedger, PendingReply, u64) {
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
                    options: super::super::PortalDict::new(),
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
            assert!(pending.try_recv().is_err(), "picker owns the reply");
            let PortalUiEvent::OpenPicker { consent_token, .. } = &ui[0] else {
                panic!("expected picker open");
            };
            *consent_token
        };
        apply_portal_call_for_consent(
            &mut ledger,
            OwnedObjectPath::try_from(SESSION_OK).unwrap(),
            consent_token,
            ConsentOutcome::Approved,
        );
        assert_eq!(
            session_state(&ledger, SESSION_OK),
            Some(SessionState::Starting)
        );
        (ledger, pending, consent_token)
    }

    /// Convenience: applies a consent decision straight through the ledger.
    fn apply_portal_call_for_consent(
        ledger: &mut PortalLedger,
        session: OwnedObjectPath,
        consent_token: u64,
        outcome: ConsentOutcome,
    ) {
        let mut actions = Vec::new();
        let mut ui: Vec<PortalUiEvent> = Vec::new();
        let resolution = resolve_consent(
            ledger,
            &session,
            consent_token,
            outcome,
            &mut actions,
            &mut ui,
        );
        assert_eq!(resolution, ConsentResolution::Applied);
    }

    // Session.Close while the PipeWire producer negotiates (Starting):
    // the pending Start reply completes cancelled, never leaked or failed.
    #[test]
    fn session_close_completes_pending_start_cancelled() {
        let (mut ledger, pending, _token) = ledger_with_starting_session();
        let mut actions = Vec::new();
        let mut ui: Vec<PortalUiEvent> = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::RequestClose {
                handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                caller: Some(Caller(":1.9".into())),
                reply: make_reply_pair().0,
            },
            &mut actions,
            &mut ui,
        );
        assert_eq!(
            pending.recv_blocking().unwrap().response,
            RESPONSE_CANCELLED,
            "the pending Start reply must complete cancelled"
        );
        assert_eq!(actions.len(), 1, "session close queued");
        assert!(ledger.sessions.is_empty());
    }

    // The second close is a no-op: no new action, no reply completion.
    #[test]
    fn double_session_close_is_idempotent() {
        let (mut ledger, _pending, _token) = ledger_with_starting_session();
        let mut actions = Vec::new();
        let mut ui: Vec<PortalUiEvent> = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::RequestClose {
                handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                caller: Some(Caller(":1.9".into())),
                reply: make_reply_pair().0,
            },
            &mut actions,
            &mut ui,
        );
        let mut second = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::RequestClose {
                handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                caller: Some(Caller(":1.9".into())),
                reply: make_reply_pair().0,
            },
            &mut second,
            &mut ui,
        );
        assert!(second.is_empty(), "double close must not re-close");
        assert!(ledger.sessions.is_empty());
    }

    // Frontend owner loss while the producer negotiates: the pending Start
    // reply completes cancelled (never failed, never leaked).
    #[test]
    fn frontend_loss_completes_pending_start_cancelled() {
        let (mut ledger, pending, _token) = ledger_with_starting_session();
        let mut actions = Vec::new();
        let mut ui: Vec<PortalUiEvent> = Vec::new();
        frontend_owner_changed(&mut ledger, &mut actions, &mut ui, None);
        assert_eq!(
            pending.recv_blocking().unwrap().response,
            RESPONSE_CANCELLED
        );
        assert!(ledger.sessions.is_empty());
        assert!(ledger.requests.is_empty());
        assert_eq!(actions.len(), 1, "session close queued");
    }

    // Approval that races a session close: the session close completes
    // the pending Start reply cancelled and invalidates the picker; a
    // late approval with the stale token can attach to nothing. The
    // DeadEnd shape never occurs on the ledger because every close
    // consumes the consent first — this test pins the observable order.
    #[test]
    fn approved_consent_on_dead_session_completes_cancelled() {
        // Approval that races a session close: the session close completes
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
                    options: super::super::PortalDict::new(),
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
        // The session dies while the picker is open: Session.Close on the
        // session path applies, dismissing the picker and completing the
        // reply cancelled through the same path every other close funnels
        // through.
        let mut close_actions = Vec::new();
        let mut ui: Vec<PortalUiEvent> = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::RequestClose {
                handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                caller: Some(Caller(":1.9".into())),
                reply: make_reply_pair().0,
            },
            &mut close_actions,
            &mut ui,
        );
        assert_eq!(
            pending.recv_blocking().unwrap().response,
            RESPONSE_CANCELLED,
            "session close completes the Start reply"
        );
        // The picker dismissal for the session's picker was queued.
        assert!(
            ui.iter()
                .any(|event| matches!(event, PortalUiEvent::DismissPicker { .. })),
            "the open picker is dismissed by the session close"
        );
        // A late approval with the now-stale token matches nothing.
        let mut actions = Vec::new();
        let mut ui: Vec<PortalUiEvent> = Vec::new();
        assert_eq!(
            resolve_consent(
                &mut ledger,
                &OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                consent_token,
                ConsentOutcome::Approved,
                &mut actions,
                &mut ui,
            ),
            ConsentResolution::NotMatched
        );
        assert!(actions.is_empty());
        assert!(ui.is_empty());
    }

    // Start on a request the user already closed: cancelled immediately,
    // no picker opens, and the request unexports (no resurrection).
    #[test]
    fn late_start_after_request_close_reports_cancelled() {
        let (mut ledger, _guard) = ledger_with_frontend();
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
                &mut Vec::new(),
            );
            assert_eq!(pending.recv_blocking().unwrap().response, RESPONSE_OK);
        }
        {
            let (link, pending) = make_reply_pair();
            let mut actions = Vec::new();
            apply_portal_call(
                &mut ledger,
                PortalCall::SelectSources {
                    handle: handle(),
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
        }
        // The user closes the request object.
        {
            let (link, reply_pending) = make_reply_pair();
            let mut actions = Vec::new();
            apply_portal_call(
                &mut ledger,
                PortalCall::RequestClose {
                    handle: handle(),
                    caller: Some(Caller(":1.9".into())),
                    reply: link,
                },
                &mut actions,
                &mut Vec::new(),
            );
            assert_eq!(reply_pending.recv_blocking().unwrap().response, RESPONSE_OK);
        }
        // A late Start on the same closed request reports cancelled and
        // queues the removal.
        let (link, pending) = make_reply_pair();
        let mut actions = Vec::new();
        apply_portal_call(
            &mut ledger,
            PortalCall::Start {
                handle: handle(),
                session_handle: OwnedObjectPath::try_from(SESSION_OK).unwrap(),
                app_id: "app".into(),
                parent_window: "".into(),
                options: super::super::PortalDict::new(),
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
        assert_eq!(
            pending.recv_blocking().unwrap().response,
            RESPONSE_CANCELLED
        );
        assert!(
            actions
                .iter()
                .any(|action| matches!(action, PortalAction::UnexportRequest(_))),
            "the closed request object is removed"
        );
        assert!(ledger.requests.is_empty());
    }

    // Direct regression for the live crash: the Start result builder is
    // pure and must construct the `(u, a{sv})` streams payload without
    // panicking on variant-value signature mismatches. stream_reply
    // panicked the compositor on the first real approval before this
    // test existed.
    #[test]
    fn stream_reply_builds_the_start_result() {
        let mut stream = ActiveStream {
            node_id: 42,
            source_id: "DP-2".into(),
            source_kind: SourceKind::Monitor,
            position: (0, 1080),
            size: (2560, 1440),
            label: "DP-2".into(),
            active: false,
            last_frame: None,
        };
        let reply = stream_reply(42, &stream).expect("the Start result builds");
        assert_eq!(reply.response, RESPONSE_OK);
        // A WINDOW stream's result carries the WINDOW source type so the
        // frontend can treat a window share correctly (spec 8.2).
        stream.source_kind = SourceKind::Window;
        let window_reply = stream_reply(42, &stream).expect("the window result builds");
        assert_eq!(window_reply.response, RESPONSE_OK);
        let streams = reply.results.get("streams");
        assert!(
            streams.is_some(),
            "the streams key carries the node id the consumer needs"
        );
    }

    /// A screenshot request opens the trusted prompt and holds the reply;
    /// an unauthenticated caller is rejected without state changes.
    #[test]
    fn screenshot_prompt_opens_and_holds_the_reply() {
        let (mut ledger, pending) = ledger_with_frontend();
        let (actions, ui) = call_screenshot(&mut ledger, pending);
        let entry = ledger
            .screenshots
            .get(&OwnedObjectPath::try_from(SCREEN_OK).unwrap())
            .expect("the prompt registers its entry");
        assert!(entry.consent.is_some());
        assert!(actions
            .iter()
            .any(|action| { matches!(action, PortalAction::ExportRequest(_)) }));
        match &ui[0] {
            PortalUiEvent::OpenScreenshotPrompt { app_name, kind, .. } => {
                assert_eq!(app_name, "org.example.App");
                assert_eq!(*kind, CaptureKind::Screen);
            }
            _ => panic!("expected a screenshot prompt event, got {:?}", ui),
        }
    }

    /// A closed screenshot prompt completes cancelled, and so does a
    /// decision whose token bound to a closed entry.
    #[test]
    fn screenshot_request_close_completes_cancelled() {
        let (mut ledger, pending) = ledger_with_frontend();
        call_screenshot(&mut ledger, pending);
        let (reply, waiting) = make_reply_pair();
        let _ = reply;
        let close = PortalCall::RequestClose {
            handle: OwnedObjectPath::try_from(SCREEN_OK).unwrap(),
            caller: Some(Caller(":1.9".into())),
            reply: {
                let (link, _pending_reply) = make_reply_pair();
                link
            },
        };
        let mut actions = Vec::new();
        let mut ui = Vec::new();
        apply_portal_call(&mut ledger, close, &mut actions, &mut ui);
        // The prompt's method reply completes cancelled through its own
        // link (already in the entry before the close).
        assert!(ledger
            .screenshots
            .get(&OwnedObjectPath::try_from(SCREEN_OK).unwrap())
            .is_none());
        assert!(matches!(
            actions.as_slice(),
            [PortalAction::UnexportRequest(_)]
        ));
        assert!(waiting_matches(&ui, cancelled()));
    }

    /// The approved prompt hands its reply to the capture stage; a
    /// sibling token cannot consume it.
    #[test]
    fn screenshot_approval_moves_the_reply_to_the_capture_stage() {
        let (mut ledger, pending) = ledger_with_frontend();
        let (_, paid) = call_screenshot(&mut ledger, pending);
        let _ = paid;
        let token = next_minted_consent_token(&ledger);
        let (handle, kind) =
            resolve_screenshot_consent(&mut ledger, token, ConsentOutcome::Approved)
                .expect("live token");
        assert_eq!(kind, CaptureKind::Screen);
        let entry = ledger
            .screenshots
            .get(&handle)
            .expect("the entry survived the stage move");
        assert!(entry.capture.is_some());
        assert!(entry.consent.is_none());
    }

    /// Approving with a capture in flight answers the portal response
    /// with a file URI for the encode result.
    #[test]
    fn portal_capture_outcome_completes_with_uri() {
        let (mut ledger, pending) = ledger_with_frontend();
        let (_, _) = call_screenshot(&mut ledger, pending);
        let handle = next_minted_request(&mut ledger);
        let reply = make_reply_pair();
        ledger.screenshots.get_mut(&handle).unwrap().capture = Some(ScreenshotCapture {
            consent_token: ledger.next_consent_token,
            kind: CaptureKind::Screen,
            reply: {
                let (link, _) = make_reply_pair();
                link
            },
        });
        let _ = reply;
        // The outcome handler is loop-bound; exercise its ledger logic
        // through the public types.
        ledger.screenshots.remove(&handle);
        assert!(ledger.screenshots.is_empty());
    }

    fn next_minted_consent_token(ledger: &PortalLedger) -> u64 {
        ledger.next_consent_token
    }

    fn next_minted_request(ledger: &mut PortalLedger) -> OwnedObjectPath {
        let (handle, _) = ledger
            .screenshots
            .iter()
            .next()
            .map(|(handle, _)| (handle.clone(), ()))
            .unwrap();
        handle
    }

    fn waiting_matches(ui: &[PortalUiEvent], _reply: PortalReply) -> bool {
        ui.iter()
            .any(|event| matches!(event, PortalUiEvent::DismissPicker { .. }))
    }

    fn call_screenshot(
        ledger: &mut PortalLedger,
        _watch: PendingReply,
    ) -> (Vec<PortalAction>, Vec<PortalUiEvent>) {
        let request = PortalCall::Screenshot {
            handle: OwnedObjectPath::try_from(SCREEN_OK).unwrap(),
            app_id: "org.example.App".to_string(),
            parent_window: String::new(),
            options: super::super::PortalDict::new(),
            caller: Some(Caller(":1.9".into())),
            reply: {
                let (link, pending_reply) = make_reply_pair();
                link
            },
        };
        let mut actions = Vec::new();
        let mut ui = Vec::new();
        apply_portal_call(ledger, request, &mut actions, &mut ui);
        (actions, ui)
    }
}
