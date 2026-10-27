//! Minimal PAM client used by the lock screen.
//!
//! Each authentication attempt runs one PAM transaction (`pam_start` ->
//! `pam_authenticate` -> `pam_end`) on its own thread: PAM modules block
//! (password prompts, the fingerprint reader, `pam_faildelay`), so they must
//! never run on the compositor loop. The conversation forwards every PAM
//! message to the loop through a calloop channel; a prompt then blocks the
//! worker until the shell answers it, or until the answer channel is dropped,
//! which cancels the transaction.

use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::sync::mpsc;

use smithay::reexports::calloop::channel;
use tracing::{debug, warn};

/// PAM service of the password stack (`/etc/pam.d/veshell`).
pub const PASSWORD_SERVICE: &str = "veshell";
/// PAM service of the fingerprint stack (`/etc/pam.d/veshell-fingerprint`).
pub const FINGERPRINT_SERVICE: &str = "veshell-fingerprint";

const PAM_SUCCESS: c_int = 0;
const PAM_BUF_ERR: c_int = 5;
const PAM_AUTH_ERR: c_int = 7;
const PAM_CONV_ERR: c_int = 19;

const PAM_PROMPT_ECHO_OFF: c_int = 1;
const PAM_PROMPT_ECHO_ON: c_int = 2;
const PAM_ERROR_MSG: c_int = 3;
const PAM_TEXT_INFO: c_int = 4;

#[repr(C)]
struct PamMessage {
    msg_style: c_int,
    msg: *const c_char,
}

#[repr(C)]
struct PamResponse {
    resp: *mut c_char,
    resp_retcode: c_int,
}

type ConvFn = unsafe extern "C" fn(
    num_msg: c_int,
    msg: *mut *const PamMessage,
    resp: *mut *mut PamResponse,
    appdata_ptr: *mut c_void,
) -> c_int;

#[repr(C)]
struct PamConv {
    conv: Option<ConvFn>,
    appdata_ptr: *mut c_void,
}

#[link(name = "pam")]
extern "C" {
    fn pam_start(
        service_name: *const c_char,
        user: *const c_char,
        pam_conversation: *const PamConv,
        pamh: *mut *mut c_void,
    ) -> c_int;
    fn pam_authenticate(pamh: *mut c_void, flags: c_int) -> c_int;
    fn pam_end(pamh: *mut c_void, pam_status: c_int) -> c_int;
    fn pam_strerror(pamh: *mut c_void, errnum: c_int) -> *const c_char;
}

/// Which PAM stack a message comes from.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AuthSource {
    Password,
    Fingerprint,
}

impl AuthSource {
    pub fn as_str(self) -> &'static str {
        match self {
            AuthSource::Password => "password",
            AuthSource::Fingerprint => "fingerprint",
        }
    }
}

/// Final result of one PAM transaction.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AuthOutcome {
    Success,
    /// The credentials were rejected (`PAM_AUTH_ERR`).
    Rejected,
    /// Any other PAM failure, with PAM's own description.
    Failed(String),
    /// The stack cannot run for this user (no fingerprint enrolled, no reader).
    Unavailable,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum AuthEvent {
    /// PAM asks for input. `echo` is false for secrets.
    Prompt {
        message: String,
        echo: bool,
    },
    Info(String),
    Error(String),
    Finished(AuthOutcome),
}

/// A message from a worker, tagged so the loop can drop stale ones.
#[derive(Debug, Clone)]
pub struct AuthMessage {
    pub generation: u64,
    pub source: AuthSource,
    pub event: AuthEvent,
}

/// Answers the pending prompt of a worker. Dropping it cancels the transaction
/// at its next prompt.
pub struct Responder(mpsc::Sender<String>);

impl Responder {
    pub fn respond(&self, response: String) -> bool {
        self.0.send(response).is_ok()
    }
}

struct Conversation {
    generation: u64,
    source: AuthSource,
    events: channel::Sender<AuthMessage>,
    responses: mpsc::Receiver<String>,
}

impl Conversation {
    fn send(&self, event: AuthEvent) -> bool {
        self.events
            .send(AuthMessage {
                generation: self.generation,
                source: self.source,
                event,
            })
            .is_ok()
    }
}

/// Starts one PAM transaction of `service` for `user` on a worker thread.
pub fn spawn(
    source: AuthSource,
    service: &'static str,
    user: String,
    generation: u64,
    events: channel::Sender<AuthMessage>,
) -> Responder {
    let (sender, responses) = mpsc::channel();
    let conversation = Conversation {
        generation,
        source,
        events,
        responses,
    };
    let spawned = std::thread::Builder::new()
        .name(format!("pam-{}", source.as_str()))
        .spawn(move || {
            let outcome = if source == AuthSource::Fingerprint && !fingerprint_enrolled(&user) {
                AuthOutcome::Unavailable
            } else {
                authenticate(service, &user, &conversation)
            };
            debug!(source = source.as_str(), ?outcome, "PAM transaction ended");
            conversation.send(AuthEvent::Finished(outcome));
        });
    if let Err(error) = spawned {
        warn!(?error, "Failed to spawn the PAM worker");
    }
    Responder(sender)
}

fn authenticate(service: &str, user: &str, conversation: &Conversation) -> AuthOutcome {
    let (Ok(service), Ok(user)) = (CString::new(service), CString::new(user)) else {
        return AuthOutcome::Failed("invalid service or user name".into());
    };
    let conv = PamConv {
        conv: Some(converse),
        appdata_ptr: conversation as *const Conversation as *mut c_void,
    };
    let mut handle: *mut c_void = std::ptr::null_mut();
    // SAFETY: every pointer outlives the transaction: `conv` and
    // `conversation` live on this stack frame until `pam_end` returns.
    unsafe {
        let status = pam_start(service.as_ptr(), user.as_ptr(), &conv, &mut handle);
        if status != PAM_SUCCESS {
            return AuthOutcome::Failed(error_string(handle, status));
        }
        let status = pam_authenticate(handle, 0);
        let outcome = match status {
            PAM_SUCCESS => AuthOutcome::Success,
            PAM_AUTH_ERR => AuthOutcome::Rejected,
            _ => AuthOutcome::Failed(error_string(handle, status)),
        };
        pam_end(handle, status);
        outcome
    }
}

unsafe fn error_string(handle: *mut c_void, status: c_int) -> String {
    let text = pam_strerror(handle, status);
    if text.is_null() {
        return format!("PAM error {status}");
    }
    CStr::from_ptr(text).to_string_lossy().into_owned()
}

/// The PAM conversation callback.
///
/// Linux-PAM passes `msg` as an array of `num_msg` pointers. The response
/// array and its strings are allocated with `malloc`: PAM frees them.
unsafe extern "C" fn converse(
    num_msg: c_int,
    msg: *mut *const PamMessage,
    resp: *mut *mut PamResponse,
    appdata_ptr: *mut c_void,
) -> c_int {
    if num_msg <= 0 || msg.is_null() || resp.is_null() || appdata_ptr.is_null() {
        return PAM_CONV_ERR;
    }
    let conversation = &*(appdata_ptr as *const Conversation);
    let count = num_msg as usize;
    let responses = libc::calloc(count, std::mem::size_of::<PamResponse>()) as *mut PamResponse;
    if responses.is_null() {
        return PAM_BUF_ERR;
    }

    for index in 0..count {
        let message = &**msg.add(index);
        let text = if message.msg.is_null() {
            String::new()
        } else {
            CStr::from_ptr(message.msg).to_string_lossy().into_owned()
        };
        let reply = match message.msg_style {
            PAM_PROMPT_ECHO_OFF | PAM_PROMPT_ECHO_ON => {
                let echo = message.msg_style == PAM_PROMPT_ECHO_ON;
                if !conversation.send(AuthEvent::Prompt {
                    message: text,
                    echo,
                }) {
                    free_responses(responses, count);
                    return PAM_CONV_ERR;
                }
                // A dropped responder cancels the transaction.
                let Ok(answer) = conversation.responses.recv() else {
                    free_responses(responses, count);
                    return PAM_CONV_ERR;
                };
                let copy = secret_to_c(answer);
                if copy.is_null() {
                    free_responses(responses, count);
                    return PAM_BUF_ERR;
                }
                copy
            }
            PAM_ERROR_MSG => {
                conversation.send(AuthEvent::Error(text));
                std::ptr::null_mut()
            }
            PAM_TEXT_INFO => {
                conversation.send(AuthEvent::Info(text));
                std::ptr::null_mut()
            }
            _ => {
                free_responses(responses, count);
                return PAM_CONV_ERR;
            }
        };
        (*responses.add(index)).resp = reply;
    }

    *resp = responses;
    PAM_SUCCESS
}

/// Copies `secret` into a `malloc`ed C string for PAM and wipes the Rust copy.
fn secret_to_c(secret: String) -> *mut c_char {
    let mut bytes = secret.into_bytes();
    // An interior NUL cannot be represented: PAM would see a truncated secret.
    let copy = if bytes.contains(&0) {
        std::ptr::null_mut()
    } else {
        // SAFETY: the buffer has room for the bytes and the terminating NUL.
        unsafe {
            let copy = libc::malloc(bytes.len() + 1) as *mut u8;
            if !copy.is_null() {
                std::ptr::copy_nonoverlapping(bytes.as_ptr(), copy, bytes.len());
                *copy.add(bytes.len()) = 0;
            }
            copy as *mut c_char
        }
    };
    wipe(&mut bytes);
    copy
}

fn wipe(bytes: &mut [u8]) {
    for byte in bytes.iter_mut() {
        // Volatile so the compiler cannot drop the wipe of a dying buffer.
        unsafe { std::ptr::write_volatile(byte, 0) };
    }
}

unsafe fn free_responses(responses: *mut PamResponse, count: usize) {
    for index in 0..count {
        let reply = (*responses.add(index)).resp;
        if !reply.is_null() {
            let length = libc::strlen(reply);
            for offset in 0..length {
                std::ptr::write_volatile(reply.add(offset), 0);
            }
            libc::free(reply as *mut c_void);
        }
    }
    libc::free(responses as *mut c_void);
}

/// Whether fprintd has at least one enrolled finger for `user`.
///
/// The fingerprint stack only runs when this is true: without an enrolled
/// finger `pam_fprintd` fails at once, and without fprintd the service is
/// pointless.
fn fingerprint_enrolled(user: &str) -> bool {
    let result: zbus::Result<bool> = zbus::block_on(async {
        let connection = zbus::Connection::system().await?;
        let manager = zbus::Proxy::new(
            &connection,
            "net.reactivated.Fprint",
            "/net/reactivated/Fprint/Manager",
            "net.reactivated.Fprint.Manager",
        )
        .await?;
        let device: zbus::zvariant::OwnedObjectPath = manager.call("GetDefaultDevice", &()).await?;
        let device = zbus::Proxy::new(
            &connection,
            "net.reactivated.Fprint",
            device,
            "net.reactivated.Fprint.Device",
        )
        .await?;
        let fingers: Vec<String> = device.call("ListEnrolledFingers", &(user,)).await?;
        Ok(!fingers.is_empty())
    });
    match result {
        Ok(enrolled) => enrolled,
        Err(error) => {
            debug!(?error, "No fingerprint available for the lock screen");
            false
        }
    }
}

/// Login name and display name of the user running the compositor.
pub fn current_user() -> (String, String) {
    // SAFETY: `getpwuid_r` writes into the buffers we own.
    unsafe {
        let mut passwd: libc::passwd = std::mem::zeroed();
        let mut buffer = vec![0 as c_char; 16 * 1024];
        let mut result: *mut libc::passwd = std::ptr::null_mut();
        let status = libc::getpwuid_r(
            libc::getuid(),
            &mut passwd,
            buffer.as_mut_ptr(),
            buffer.len(),
            &mut result,
        );
        if status != 0 || result.is_null() || passwd.pw_name.is_null() {
            let name = std::env::var("USER").unwrap_or_default();
            return (name.clone(), name);
        }
        let name = CStr::from_ptr(passwd.pw_name)
            .to_string_lossy()
            .into_owned();
        let gecos = if passwd.pw_gecos.is_null() {
            String::new()
        } else {
            CStr::from_ptr(passwd.pw_gecos)
                .to_string_lossy()
                .into_owned()
        };
        (name.clone(), display_name_from_gecos(&gecos, &name))
    }
}

/// The full name is the first comma-separated GECOS field; fall back to the
/// login name when it is empty.
fn display_name_from_gecos(gecos: &str, login: &str) -> String {
    let full_name = gecos.split(',').next().unwrap_or("").trim();
    if full_name.is_empty() {
        login.to_string()
    } else {
        full_name.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn display_name_uses_the_first_gecos_field() {
        assert_eq!(
            display_name_from_gecos("Ada Lovelace,,,", "ada"),
            "Ada Lovelace"
        );
    }

    #[test]
    fn display_name_falls_back_to_the_login() {
        assert_eq!(display_name_from_gecos("", "ada"), "ada");
        assert_eq!(display_name_from_gecos(" ,room", "ada"), "ada");
    }

    #[test]
    fn secrets_with_an_interior_nul_are_refused() {
        assert!(secret_to_c("a\0b".to_string()).is_null());
    }

    #[test]
    fn secrets_are_copied_with_a_terminator() {
        let copy = secret_to_c("hunter2".to_string());
        assert!(!copy.is_null());
        unsafe {
            assert_eq!(CStr::from_ptr(copy).to_str().unwrap(), "hunter2");
            libc::free(copy as *mut c_void);
        }
    }
}
