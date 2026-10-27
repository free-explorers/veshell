//! Session lock screen.
//!
//! The compositor owns the lock: while it is set, no input reaches a client
//! (keys, pointer, scroll), game surfaces drawn over the Flutter frame are
//! hidden, and only a successful PAM transaction (or logind's `Unlock`) clears
//! it. The shell only draws the lock screen and relays what the user types, so
//! a stuck or restarting shell can never leave the session open.
//!
//! See `docs/specifications/lock_screen.md`.

use std::path::Path;
use std::time::Duration;

use serde_json::json;
use smithay::reexports::calloop::channel;
use smithay::reexports::calloop::timer::{TimeoutAction, Timer};
use smithay::utils::{IsAlive, Logical, Point, SERIAL_COUNTER};
use tracing::{info, warn};

use crate::backend::Backend;
use crate::focus::{KeyboardFocusTarget, PointerFocusTarget};
use crate::state::State;

mod dbus;
pub mod pam;

use dbus::{LockDbusCommand, LockDbusEvent};
use pam::{AuthEvent, AuthMessage, AuthOutcome, AuthSource, Responder};

/// Consecutive fingerprint transactions that may end without success before
/// the reader is left alone. A failed password attempt re-arms it.
const FINGERPRINT_ATTEMPTS: u32 = 3;

/// Grace between the shell reporting the lock screen drawn and the suspend
/// going ahead, so the frame reaches the panel first.
const SLEEP_RELEASE_DELAY: Duration = Duration::from_millis(150);

pub struct LockState {
    locked: bool,
    /// Bumped on every lock and unlock; worker messages from an older
    /// generation are dropped.
    generation: u64,
    user_name: String,
    real_name: String,
    /// Keyboard focus the lock took away, restored on unlock.
    saved_keyboard_focus: Option<KeyboardFocusTarget>,
    password: Option<Responder>,
    /// Whether the current password transaction asked something. A stack that
    /// fails without prompting (a broken PAM file) is not restarted on its own,
    /// or it would spin.
    password_prompted: bool,
    /// The prompt the password stack is waiting on, replayed to a restarted
    /// shell.
    pending_prompt: Option<(String, bool)>,
    /// An answer typed while no password transaction was waiting; handed to
    /// the next one's first prompt.
    queued_response: Option<String>,
    fingerprint_running: bool,
    fingerprint_failures: u32,
    fingerprint_message: Option<(String, String)>,
    /// The shell has drawn the lock screen of this generation.
    shown: bool,
    /// A suspend is waiting for the lock screen to be drawn.
    sleep_pending: bool,
    auth_events: channel::Sender<AuthMessage>,
    dbus: Option<async_channel::Sender<LockDbusCommand>>,
}

impl LockState {
    pub fn new<BackendData: Backend + 'static>(
        loop_handle: &smithay::reexports::calloop::LoopHandle<'static, State<BackendData>>,
    ) -> Self {
        let (auth_events, auth_receiver) = channel::channel::<AuthMessage>();
        loop_handle
            .insert_source(auth_receiver, |event, _, state: &mut State<BackendData>| {
                if let channel::Event::Msg(message) = event {
                    on_auth_message(state, message);
                }
            })
            .expect("Failed to register the lock screen PAM source");

        let dbus = BackendData::RUNS_PORTAL_BACKEND.then(|| {
            let (events, receiver) = channel::channel::<LockDbusEvent>();
            loop_handle
                .insert_source(receiver, |event, _, state: &mut State<BackendData>| {
                    if let channel::Event::Msg(event) = event {
                        on_dbus_event(state, event);
                    }
                })
                .expect("Failed to register the logind lock source");
            dbus::spawn(events)
        });

        let (user_name, real_name) = pam::current_user();
        Self {
            locked: false,
            generation: 0,
            user_name,
            real_name,
            saved_keyboard_focus: None,
            password: None,
            password_prompted: false,
            pending_prompt: None,
            queued_response: None,
            fingerprint_running: false,
            fingerprint_failures: 0,
            fingerprint_message: None,
            shown: false,
            sleep_pending: false,
            auth_events,
            dbus,
        }
    }

    pub fn is_locked(&self) -> bool {
        self.locked
    }

    fn command(&self, command: LockDbusCommand) {
        if let Some(dbus) = &self.dbus {
            let _ = dbus.try_send(command);
        }
    }

    /// Records a keyboard focus requested while locked, so unlocking lands on
    /// the window the user (or the shell) picked last.
    pub fn defer_keyboard_focus(&mut self, target: Option<KeyboardFocusTarget>) {
        self.saved_keyboard_focus = target;
    }

    /// Forgets a deferred focus that pointed at `target`.
    pub fn forget_keyboard_focus(&mut self, target: &KeyboardFocusTarget) {
        if self.saved_keyboard_focus.as_ref() == Some(target) {
            self.saved_keyboard_focus = None;
        }
    }
}

impl<BackendData: Backend + 'static> State<BackendData> {
    pub fn is_locked(&self) -> bool {
        self.lock.is_locked()
    }

    /// Whether input is routed straight to the gaming-mode client. Never while
    /// locked: the lock screen takes the input back.
    pub fn gaming_input_active(&self) -> bool {
        self.meta_window_state.meta_window_in_gaming_mode.is_some() && !self.is_locked()
    }

    /// The pointer focus handed to Smithay. `None` while locked, so clients
    /// get a leave and no motion, button or scroll.
    pub fn client_pointer_focus(&self) -> Option<(PointerFocusTarget, Point<f64, Logical>)> {
        if self.is_locked() {
            None
        } else {
            self.pointer_focus.clone()
        }
    }
}

/// Locks the session. Idempotent.
pub fn lock<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    if state.lock.locked {
        return;
    }
    info!("Locking the session");
    state.lock.locked = true;
    state.lock.generation += 1;
    state.lock.shown = false;
    state.lock.fingerprint_failures = 0;
    state.lock.fingerprint_message = None;
    state.lock.queued_response = None;

    // Take every input path away from clients.
    if state.capture_state.session.is_some() {
        crate::capture::cancel_capture_session(state);
    }
    state.end_floating_move();
    state.end_floating_resize();
    crate::keyboard::release_game_mode_forwarded_keys(state);
    state.super_key_forwarding.clear();
    let keyboard = state.keyboard.clone();
    state.lock.saved_keyboard_focus = keyboard.current_focus();
    keyboard.set_focus(state, None, SERIAL_COUNTER.next_serial());
    state.refresh_pointer_focus();

    start_password(state);
    start_fingerprint(state);
    notify_lock_state(state);
    state.lock.command(LockDbusCommand::SetLockedHint(true));
    state.request_render();
}

/// Unlocks the session. Only called after a successful PAM transaction or on
/// logind's `Unlock`.
fn unlock<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    if !state.lock.locked {
        return;
    }
    info!("Unlocking the session");
    state.lock.locked = false;
    state.lock.generation += 1;
    // Dropping the responder cancels a password transaction waiting on its
    // prompt. A fingerprint transaction ends on its own timeout; its result is
    // stale by then.
    state.lock.password = None;
    state.lock.pending_prompt = None;
    state.lock.queued_response = None;
    state.lock.fingerprint_running = false;
    state.lock.fingerprint_message = None;
    state.lock.sleep_pending = false;

    // A game takes the keys straight from here on: Flutter must not keep
    // believing the keys it saw on the lock screen are held.
    if state.meta_window_state.meta_window_in_gaming_mode.is_some() {
        crate::keyboard::release_flutter_keys(state);
    }
    if let Some(target) = state.lock.saved_keyboard_focus.take() {
        if target.alive() {
            let keyboard = state.keyboard.clone();
            keyboard.set_focus(state, Some(target), SERIAL_COUNTER.next_serial());
        }
    }
    state.refresh_pointer_focus();

    notify_lock_state(state);
    state.lock.command(LockDbusCommand::SetLockedHint(false));
    state.request_render();
}

fn start_password<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    state.lock.password_prompted = false;
    state.lock.pending_prompt = None;
    state.lock.password = Some(pam::spawn(
        AuthSource::Password,
        password_service(),
        state.lock.user_name.clone(),
        state.lock.generation,
        state.lock.auth_events.clone(),
    ));
}

fn start_fingerprint<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    if state.lock.fingerprint_running
        || state.lock.fingerprint_failures >= FINGERPRINT_ATTEMPTS
        || !service_installed(pam::FINGERPRINT_SERVICE)
    {
        return;
    }
    state.lock.fingerprint_running = true;
    // The fingerprint stack never prompts: it has no responder to keep.
    drop(pam::spawn(
        AuthSource::Fingerprint,
        pam::FINGERPRINT_SERVICE,
        state.lock.user_name.clone(),
        state.lock.generation,
        state.lock.auth_events.clone(),
    ));
}

/// The password stack's PAM service. Without our own file (a development
/// build that was never installed), the system `login` service still
/// authenticates the user: falling back to it keeps a developer from being
/// locked out of their own session.
fn password_service() -> &'static str {
    if service_installed(pam::PASSWORD_SERVICE) {
        pam::PASSWORD_SERVICE
    } else {
        warn!(
            "PAM service '{}' is not installed; the lock screen uses 'login'",
            pam::PASSWORD_SERVICE
        );
        "login"
    }
}

/// Whether a PAM service file exists in one of Linux-PAM's lookup directories.
fn service_installed(service: &str) -> bool {
    ["/etc/pam.d", "/usr/lib/pam.d", "/usr/etc/pam.d"]
        .iter()
        .any(|directory| Path::new(directory).join(service).is_file())
}

/// The shell answered the password prompt.
pub fn respond<BackendData: Backend + 'static>(state: &mut State<BackendData>, response: String) {
    if !state.lock.locked {
        return;
    }
    if state.lock.pending_prompt.take().is_some() {
        if let Some(responder) = &state.lock.password {
            if responder.respond(response) {
                return;
            }
        }
        return;
    }
    // No transaction is waiting (it ended without prompting): run a fresh one
    // and hand it this answer.
    state.lock.queued_response = Some(response);
    if state.lock.password.is_none() {
        start_password(state);
    }
}

/// The shell drew the lock screen: a suspend waiting for it may go ahead.
pub fn on_shown<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    if !state.lock.locked {
        return;
    }
    state.lock.shown = true;
    if state.lock.sleep_pending {
        state.lock.sleep_pending = false;
        release_sleep_after_delay(state);
    }
}

fn release_sleep_after_delay<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    let result = state.loop_handle.insert_source(
        Timer::from_duration(SLEEP_RELEASE_DELAY),
        |_, _, state: &mut State<BackendData>| {
            state.lock.command(LockDbusCommand::ReleaseSleepInhibitor);
            TimeoutAction::Drop
        },
    );
    if result.is_err() {
        state.lock.command(LockDbusCommand::ReleaseSleepInhibitor);
    }
}

fn on_dbus_event<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    event: LockDbusEvent,
) {
    match event {
        LockDbusEvent::Lock => lock(state),
        LockDbusEvent::Unlock => unlock(state),
        LockDbusEvent::PrepareForSleep => {
            if state.lock.locked && state.lock.shown {
                state.lock.command(LockDbusCommand::ReleaseSleepInhibitor);
            } else {
                state.lock.sleep_pending = true;
                lock(state);
            }
        }
    }
}

fn on_auth_message<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    message: AuthMessage,
) {
    if !state.lock.locked || message.generation != state.lock.generation {
        return;
    }
    match (message.source, message.event) {
        (AuthSource::Password, AuthEvent::Prompt { message, echo }) => {
            state.lock.password_prompted = true;
            if let Some(response) = state.lock.queued_response.take() {
                if let Some(responder) = &state.lock.password {
                    responder.respond(response);
                }
                return;
            }
            state.lock.pending_prompt = Some((message.clone(), echo));
            send_auth_message(state, AuthSource::Password, "prompt", &message, echo);
        }
        (AuthSource::Password, AuthEvent::Info(text)) => {
            send_auth_message(state, AuthSource::Password, "info", &text, false);
        }
        (AuthSource::Password, AuthEvent::Error(text)) => {
            send_auth_message(state, AuthSource::Password, "error", &text, false);
        }
        (AuthSource::Password, AuthEvent::Finished(outcome)) => {
            state.lock.password = None;
            state.lock.pending_prompt = None;
            state.lock.queued_response = None;
            match outcome {
                AuthOutcome::Success => unlock(state),
                outcome => {
                    let text = match &outcome {
                        AuthOutcome::Failed(text) => text.clone(),
                        _ => String::new(),
                    };
                    send_auth_message(state, AuthSource::Password, "failed", &text, false);
                    // A typed attempt re-arms the fingerprint reader.
                    state.lock.fingerprint_failures = 0;
                    start_fingerprint(state);
                    if state.lock.password_prompted {
                        start_password(state);
                    } else {
                        warn!(?outcome, "The password stack failed without prompting");
                    }
                }
            }
        }
        (AuthSource::Fingerprint, AuthEvent::Prompt { .. }) => {
            // Nothing answers fingerprint prompts; the responder is gone, so
            // the transaction is cancelled on its own.
        }
        (AuthSource::Fingerprint, AuthEvent::Info(text)) => {
            state.lock.fingerprint_message = Some(("info".into(), text.clone()));
            send_auth_message(state, AuthSource::Fingerprint, "info", &text, false);
        }
        (AuthSource::Fingerprint, AuthEvent::Error(text)) => {
            state.lock.fingerprint_message = Some(("error".into(), text.clone()));
            send_auth_message(state, AuthSource::Fingerprint, "error", &text, false);
        }
        (AuthSource::Fingerprint, AuthEvent::Finished(outcome)) => {
            state.lock.fingerprint_running = false;
            match outcome {
                AuthOutcome::Success => unlock(state),
                AuthOutcome::Unavailable => {
                    state.lock.fingerprint_failures = FINGERPRINT_ATTEMPTS;
                    state.lock.fingerprint_message = None;
                    send_auth_message(state, AuthSource::Fingerprint, "unavailable", "", false);
                }
                _ => {
                    state.lock.fingerprint_failures += 1;
                    if state.lock.fingerprint_failures < FINGERPRINT_ATTEMPTS {
                        start_fingerprint(state);
                    } else {
                        state.lock.fingerprint_message = None;
                        send_auth_message(state, AuthSource::Fingerprint, "unavailable", "", false);
                    }
                }
            }
        }
    }
}

fn send_auth_message<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    source: AuthSource,
    kind: &str,
    message: &str,
    echo: bool,
) {
    let Some(engine) = state.flutter_engine.as_mut() else {
        return;
    };
    engine.platform_method_channel.invoke_method(
        "lock_auth_update",
        Some(Box::new(json!({
            "source": source.as_str(),
            "kind": kind,
            "message": message,
            "echo": echo,
        }))),
        None,
    );
}

fn notify_lock_state<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    let locked = state.lock.locked;
    let user_name = state.lock.user_name.clone();
    let real_name = state.lock.real_name.clone();
    let Some(engine) = state.flutter_engine.as_mut() else {
        return;
    };
    engine.platform_method_channel.invoke_method(
        "lock_state_changed",
        Some(Box::new(json!({
            "locked": locked,
            "userName": user_name,
            "realName": real_name,
        }))),
        None,
    );
}

/// Brings a (re)started shell up to date: the lock state, the prompt the
/// password stack waits on and the last fingerprint message.
pub fn replay_to_shell<BackendData: Backend + 'static>(state: &mut State<BackendData>) {
    if !state.lock.locked {
        return;
    }
    state.lock.shown = false;
    notify_lock_state(state);
    if let Some((message, echo)) = state.lock.pending_prompt.clone() {
        send_auth_message(state, AuthSource::Password, "prompt", &message, echo);
    }
    if let Some((kind, message)) = state.lock.fingerprint_message.clone() {
        send_auth_message(state, AuthSource::Fingerprint, &kind, &message, false);
    }
}
