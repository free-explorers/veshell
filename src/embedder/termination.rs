//! Termination signals end the compositor through its normal exit path.
//!
//! Logging out (logind terminates the session), stopping the user service and
//! `Ctrl+C` in a terminal send `SIGTERM`, `SIGINT` or `SIGHUP`. By default they
//! kill the process on the spot, skipping what the event loop's exit does
//! before the devices are dropped, such as putting the outputs' colour lookup
//! tables back to neutral so the greeter or the console is not left tinted by
//! Night Light. The handlers only write to a pipe the event loop watches; the
//! loop then stops as the exit hotkey does, and the shutdown watchdog still
//! bounds the teardown.
//!
//! Handlers, unlike a blocked signal mask, are reset in the programs the
//! compositor launches, which keep the default termination behaviour.

use std::os::fd::{AsRawFd, FromRawFd, OwnedFd};
use std::sync::atomic::{AtomicI32, Ordering};

use smithay::reexports::calloop::generic::Generic;
use smithay::reexports::calloop::{Interest, LoopHandle, Mode, PostAction};
use tracing::{info, warn};

use crate::backend::Backend;
use crate::state::State;

/// The write end of the pipe, for the signal handler; `-1` until installed.
static SIGNAL_PIPE: AtomicI32 = AtomicI32::new(-1);

/// Async-signal-safe: only `write`, with `errno` preserved for the code the
/// signal interrupted.
extern "C" fn on_termination_signal(_signal: libc::c_int) {
    let fd = SIGNAL_PIPE.load(Ordering::Relaxed);
    if fd < 0 {
        return;
    }
    unsafe {
        let errno = *libc::__errno_location();
        libc::write(fd, [0u8].as_ptr().cast(), 1);
        *libc::__errno_location() = errno;
    }
}

/// Routes `SIGTERM`, `SIGINT` and `SIGHUP` to stopping the event loop.
pub fn install<BackendData: Backend + 'static>(
    loop_handle: &LoopHandle<'static, State<BackendData>>,
) {
    let mut fds = [0; 2];
    if unsafe { libc::pipe2(fds.as_mut_ptr(), libc::O_CLOEXEC | libc::O_NONBLOCK) } != 0 {
        warn!(
            "Failed to create the termination signal pipe: {}",
            std::io::Error::last_os_error()
        );
        return;
    }
    let (read_end, write_end) = unsafe { (OwnedFd::from_raw_fd(fds[0]), fds[1]) };
    let source = Generic::new(read_end, Interest::READ, Mode::Level);
    let inserted = loop_handle.insert_source(source, |_, read_end, state| {
        let mut buffer = [0u8; 16];
        // Drain: several signals may have arrived.
        while unsafe {
            libc::read(
                read_end.as_raw_fd(),
                buffer.as_mut_ptr().cast(),
                buffer.len(),
            )
        } > 0
        {}
        info!("Termination signal received: shutting down");
        state.running.store(false, Ordering::SeqCst);
        Ok(PostAction::Continue)
    });
    if let Err(err) = inserted {
        warn!("Failed to watch the termination signal pipe: {err}");
        unsafe { libc::close(write_end) };
        return;
    }
    // The write end lives as long as the process: the handler may fire at any
    // time until exit.
    SIGNAL_PIPE.store(write_end, Ordering::Relaxed);
    for signal in [libc::SIGTERM, libc::SIGINT, libc::SIGHUP] {
        unsafe {
            let mut action: libc::sigaction = std::mem::zeroed();
            action.sa_sigaction = on_termination_signal as extern "C" fn(libc::c_int) as *const ()
                as libc::sighandler_t;
            action.sa_flags = libc::SA_RESTART;
            libc::sigemptyset(&mut action.sa_mask);
            if libc::sigaction(signal, &action, std::ptr::null_mut()) != 0 {
                warn!(
                    signal,
                    "Failed to handle a termination signal: {}",
                    std::io::Error::last_os_error()
                );
            }
        }
    }
}
