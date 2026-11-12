//! The clipboard as the compositor sees it: the payloads it offers itself (a
//! native screenshot, text copied in the shell) and reading the text a client
//! or Xwayland offers, for the shell's paste.

use std::cell::RefCell;
use std::io::{ErrorKind, PipeReader, Read, Write};
use std::os::fd::OwnedFd;
use std::rc::Rc;
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use smithay::reexports::calloop::generic::Generic;
use smithay::reexports::calloop::timer::{TimeoutAction, Timer};
use smithay::reexports::calloop::{Interest, Mode, PostAction, RegistrationToken};
use smithay::wayland::selection::data_device::{
    current_data_device_selection_userdata, request_data_device_client_selection,
    set_data_device_selection, SelectionRequestError,
};
use smithay::wayland::selection::SelectionTarget;
use tracing::warn;

use crate::backend::Backend;
use crate::state::State;

pub const NATIVE_SCREENSHOT_MIME: &str = "application/x-veshell-screenshot";
pub const PNG_MIME: &str = "image/png";

/// The text MIME types, in the order a paste prefers them: UTF-8 first. The
/// shell offers all of them when it copies, as GTK does, so Wayland and X11
/// clients each find the name they ask for.
pub const TEXT_MIME_TYPES: [&str; 5] = [
    "text/plain;charset=utf-8",
    "UTF8_STRING",
    "text/plain",
    "STRING",
    "TEXT",
];

/// The largest text a paste reads; a bigger offer is cut there.
const MAX_PASTE_BYTES: usize = 16 * 1024 * 1024;

/// How long a paste waits for the owner of the clipboard to write it.
const PASTE_TIMEOUT: Duration = Duration::from_secs(2);

/// A clipboard payload the compositor owns and serves itself.
#[derive(Debug, Clone)]
pub enum NativeSelection {
    /// A screenshot, offered as PNG.
    Screenshot(Arc<Vec<u8>>),
    /// Text copied in the shell.
    Text(Arc<String>),
}

/// The user data of a compositor-set selection: `None` for one Xwayland
/// owns, which the compositor only relays.
pub type SelectionUserData = Option<NativeSelection>;

impl NativeSelection {
    /// The MIME types this payload is offered as.
    pub fn mime_types(&self) -> Vec<String> {
        match self {
            Self::Screenshot(_) => vec![PNG_MIME.to_owned(), NATIVE_SCREENSHOT_MIME.to_owned()],
            Self::Text(_) => TEXT_MIME_TYPES
                .iter()
                .map(|&mime| mime.to_owned())
                .collect(),
        }
    }

    /// Writes the payload to a requesting client's pipe when it is offered as
    /// `mime_type`. Returns whether it did: a type the payload is not offered
    /// as is refused rather than answered with the wrong bytes.
    pub fn send(&self, mime_type: &str, fd: OwnedFd) -> bool {
        let bytes: Arc<[u8]> = match self {
            Self::Screenshot(png)
                if mime_type == PNG_MIME || mime_type == NATIVE_SCREENSHOT_MIME =>
            {
                Arc::from(png.as_slice())
            }
            Self::Text(text) if TEXT_MIME_TYPES.contains(&mime_type) => Arc::from(text.as_bytes()),
            _ => return false,
        };
        write_in_background(fd, bytes);
        true
    }
}

/// Writes `bytes` to a client's pipe off the event loop: the client reads
/// at its own pace, and the loop serving it must not wait for it.
fn write_in_background(fd: OwnedFd, bytes: Arc<[u8]>) {
    thread::spawn(move || {
        let mut file = std::fs::File::from(fd);
        let mut written = 0;
        while written < bytes.len() {
            match file.write(&bytes[written..]) {
                Ok(0) => break,
                Ok(count) => written += count,
                Err(error) if error.kind() == ErrorKind::WouldBlock => {
                    thread::sleep(Duration::from_millis(1));
                }
                Err(error) => {
                    warn!(?error, "Failed to write a selection");
                    break;
                }
            }
        }
    });
}

/// Makes `selection` the clipboard, for Wayland and X11 clients alike.
pub fn set_native_clipboard<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    selection: NativeSelection,
) {
    let mime_types = selection.mime_types();
    if let Some(xwm) = state
        .xwayland_state
        .as_mut()
        .and_then(|state| state.xwm.as_mut())
    {
        if let Err(error) = xwm.new_selection(SelectionTarget::Clipboard, Some(mime_types.clone()))
        {
            warn!(?error, "Failed to publish the clipboard to Xwayland");
        }
    }
    state.clipboard_mime_types = mime_types.clone();
    set_data_device_selection(
        &state.display_handle,
        &state.seat,
        mime_types,
        Some(selection),
    );
}

/// Whether the clipboard offers text.
pub fn clipboard_has_text<BackendData: Backend + 'static>(state: &State<BackendData>) -> bool {
    state
        .clipboard_mime_types
        .iter()
        .any(|mime| TEXT_MIME_TYPES.contains(&mime.as_str()))
}

/// Reads the clipboard as text and hands it to `reply`: `None` when there is
/// no text to paste.
///
/// Text the shell copied is answered at once. Text a client or Xwayland owns
/// is read from a pipe on the event loop, which also serves that client, so
/// `reply` runs once the owner has written it, or after [`PASTE_TIMEOUT`].
pub fn read_clipboard_text<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    reply: impl FnOnce(Option<String>) + 'static,
) {
    if let Some(selection) = current_data_device_selection_userdata(&state.seat) {
        if let Some(NativeSelection::Text(text)) = selection.as_ref() {
            let text = text.to_string();
            drop(selection);
            reply(Some(text));
            return;
        }
    }

    let Ok((reader, writer)) = std::io::pipe() else {
        reply(None);
        return;
    };
    let mut writer = Some(OwnedFd::from(writer));
    for mime_type in TEXT_MIME_TYPES {
        let fd = writer
            .take()
            .expect("the write end is only handed out once");
        match request_text(state, mime_type, fd) {
            Ok(()) => {
                watch_paste(state, reader, Box::new(reply));
                return;
            }
            // Not offered as this type: try the next one with the same pipe.
            Err((Some(fd), SelectionRequestError::InvalidMimetype)) => writer = Some(fd),
            Err(_) => break,
        }
    }
    reply(None);
}

/// Asks the owner of the clipboard to write it as `mime_type` into `fd`.
/// On failure, the descriptor comes back when it was not handed out.
fn request_text<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    mime_type: &str,
    fd: OwnedFd,
) -> Result<(), (Option<OwnedFd>, SelectionRequestError)> {
    // The request consumes the descriptor even when it fails, so a copy is
    // kept to try the next MIME type.
    let spare = fd.try_clone().ok();
    match request_data_device_client_selection(&state.seat, mime_type.to_owned(), fd) {
        Ok(()) => Ok(()),
        // A compositor-set selection offered as this type: Xwayland's (the
        // shell's own text was answered before), which the compositor relays.
        Err(SelectionRequestError::ServerSideSelection) => {
            let Some(fd) = spare else {
                return Err((None, SelectionRequestError::ServerSideSelection));
            };
            match state
                .xwayland_state
                .as_mut()
                .and_then(|state| state.xwm.as_mut())
            {
                Some(xwm) => xwm
                    .send_selection(SelectionTarget::Clipboard, mime_type.to_owned(), fd)
                    .map_err(|error| {
                        warn!(?error, "Failed to read the Xwayland clipboard");
                        (None, SelectionRequestError::ServerSideSelection)
                    }),
                None => Err((None, SelectionRequestError::ServerSideSelection)),
            }
        }
        Err(error) => Err((spare, error)),
    }
}

/// A paste in progress: what was read so far, the reply still owed, and the
/// sources to remove once it is answered.
struct PendingPaste {
    bytes: Vec<u8>,
    reply: Option<Box<dyn FnOnce(Option<String>)>>,
    reader_token: Option<RegistrationToken>,
    timer_token: Option<RegistrationToken>,
}

impl PendingPaste {
    /// Answers the paste once; a later call does nothing.
    fn finish(&mut self, text: Option<String>) {
        if let Some(reply) = self.reply.take() {
            reply(text);
        }
    }
}

/// Reads the pipe on the event loop until the owner closes it, then replies
/// with the text; gives up with no text after [`PASTE_TIMEOUT`].
fn watch_paste<BackendData: Backend + 'static>(
    state: &mut State<BackendData>,
    reader: PipeReader,
    reply: Box<dyn FnOnce(Option<String>)>,
) {
    let pending = Rc::new(RefCell::new(PendingPaste {
        bytes: Vec::new(),
        reply: Some(reply),
        reader_token: None,
        timer_token: None,
    }));

    let read_pending = pending.clone();
    let reader_token = state.loop_handle.insert_source(
        Generic::new(reader, Interest::READ, Mode::Level),
        move |_, reader, state| {
            let mut pending = read_pending.borrow_mut();
            let mut chunk = [0u8; 64 * 1024];
            // Level-triggered readiness: this read does not block.
            let done = match (&**reader).read(&mut chunk) {
                Ok(0) => true,
                Ok(count) => {
                    pending.bytes.extend_from_slice(&chunk[..count]);
                    pending.bytes.len() >= MAX_PASTE_BYTES
                }
                Err(error) if error.kind() == ErrorKind::Interrupted => false,
                Err(error) => {
                    warn!(?error, "Failed to read the clipboard");
                    true
                }
            };
            if !done {
                return Ok(PostAction::Continue);
            }
            pending.bytes.truncate(MAX_PASTE_BYTES);
            let text = String::from_utf8_lossy(&pending.bytes).into_owned();
            pending.finish(Some(text));
            if let Some(token) = pending.timer_token.take() {
                state.loop_handle.remove(token);
            }
            pending.reader_token = None;
            Ok(PostAction::Remove)
        },
    );
    let Ok(reader_token) = reader_token else {
        pending.borrow_mut().finish(None);
        return;
    };
    pending.borrow_mut().reader_token = Some(reader_token);

    let timer_pending = pending.clone();
    let timer_token =
        state
            .loop_handle
            .insert_source(Timer::from_duration(PASTE_TIMEOUT), move |_, _, state| {
                let mut pending = timer_pending.borrow_mut();
                warn!("The clipboard owner did not write the clipboard in time");
                pending.finish(None);
                if let Some(token) = pending.reader_token.take() {
                    state.loop_handle.remove(token);
                }
                pending.timer_token = None;
                TimeoutAction::Drop
            });
    pending.borrow_mut().timer_token = timer_token.ok();
}

#[cfg(test)]
mod tests {
    use super::*;

    fn read_all(reader: PipeReader) -> Vec<u8> {
        let mut bytes = Vec::new();
        let mut reader = reader;
        reader.read_to_end(&mut bytes).unwrap();
        bytes
    }

    #[test]
    fn text_is_sent_as_each_text_type() {
        let selection = NativeSelection::Text(Arc::new("héllo".to_owned()));
        for mime_type in TEXT_MIME_TYPES {
            let (reader, writer) = std::io::pipe().unwrap();
            assert!(selection.send(mime_type, OwnedFd::from(writer)));
            assert_eq!(read_all(reader), "héllo".as_bytes(), "{mime_type}");
        }
    }

    #[test]
    fn a_payload_refuses_a_type_it_is_not_offered_as() {
        let text = NativeSelection::Text(Arc::new("text".to_owned()));
        let (_reader, writer) = std::io::pipe().unwrap();
        assert!(!text.send(PNG_MIME, OwnedFd::from(writer)));

        let screenshot = NativeSelection::Screenshot(Arc::new(vec![1, 2, 3]));
        let (_reader, writer) = std::io::pipe().unwrap();
        assert!(!screenshot.send("text/plain", OwnedFd::from(writer)));
    }

    #[test]
    fn each_payload_offers_the_types_it_sends() {
        let text = NativeSelection::Text(Arc::new(String::new()));
        assert_eq!(text.mime_types().len(), TEXT_MIME_TYPES.len());
        let screenshot = NativeSelection::Screenshot(Arc::new(Vec::new()));
        assert_eq!(screenshot.mime_types(), [PNG_MIME, NATIVE_SCREENSHOT_MIME]);
    }
}
