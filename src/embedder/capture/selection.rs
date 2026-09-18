//! Clipboard payloads owned by the capture flow: the MIME types a native
//! screenshot advertises and the worker that writes them to a requesting
//! client's pipe.

use std::io::{ErrorKind, Write};
use std::os::fd::OwnedFd;
use std::sync::Arc;
use std::thread;

use tracing::warn;

pub const NATIVE_SCREENSHOT_MIME: &str = "application/x-veshell-screenshot";
pub const PNG_MIME: &str = "image/png";
pub type SelectionUserData = Option<Arc<Vec<u8>>>;

pub(crate) fn send_native_selection(fd: OwnedFd, data: Arc<Vec<u8>>) {
    // Selection requests provide a pipe/socket owned by the receiver. Writing it on a
    // worker keeps a slow receiver from stalling the compositor event loop.
    thread::spawn(move || {
        let mut file = std::fs::File::from(fd);
        let mut written = 0;
        while written < data.len() {
            match file.write(&data[written..]) {
                Ok(0) => break,
                Ok(count) => written += count,
                Err(error) if error.kind() == ErrorKind::WouldBlock => {
                    thread::sleep(std::time::Duration::from_millis(1));
                }
                Err(error) => {
                    warn!(?error, "Failed to write native screenshot selection");
                    break;
                }
            }
        }
    });
}
