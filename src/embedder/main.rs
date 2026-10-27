use std::env;
use std::os::unix::fs::MetadataExt;
use std::os::unix::net::UnixStream;
use std::path::PathBuf;

use backend::Backend;
use build_info::BuildInfo;
use cli::{Action, Cli};
use log::debug;
use smithay::{
    reexports::wayland_server::{
        backend::{ClientData, ClientId, DisconnectReason},
        protocol::wl_surface::{self},
    },
    wayland::compositor::{
        with_surface_tree_downward, CompositorClientState, SurfaceAttributes, TraversalAction,
    },
};
use tracing_subscriber::{fmt, EnvFilter};

use crate::flutter_engine::FlutterEngine;
use crate::mouse_button_tracker::MouseButtonTracker;
use crate::state::State;

mod backend;
mod brightness;
mod build_info;
mod capture;
mod cli;
mod cursor;
mod flutter_engine;
mod focus;
mod gles_framebuffer_importer;
mod idle;
mod input_handling;
mod keyboard;
mod lock;
mod meta_window_state;
mod mouse_button_tracker;
mod notification;
mod portal;
mod settings;
mod state;
mod texture_swap_chain;
mod wayland;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = match Cli::parse(env::args().skip(1)) {
        Ok(cli) => cli,
        Err(error) => {
            eprintln!("veshell: {error}\n\n{}", Cli::USAGE);
            std::process::exit(2);
        }
    };

    // Answer informational flags before touching logging, the font cache, the
    // display backend or Flutter. `--version` has to work from a plain TTY and
    // from inside a running session.
    match cli.action {
        Action::Help => {
            print!("{}", Cli::USAGE);
            return Ok(());
        }
        Action::Version => {
            println!("{}", BuildInfo::current());
            return Ok(());
        }
        Action::Run => {}
    }

    // Set up subscriber with both stdout and file layers
    tracing_subscriber::fmt()
        .with_timer(fmt::time::ChronoLocal::new(String::from(
            "%Y-%m-%d %H:%M:%S%.3f",
        )))
        .compact()
        .with_env_filter(EnvFilter::from_default_env()) // Log level from RUST_LOG
        .init();

    debug!("Starting Veshell");

    // Font lookup and parsing are independent of display setup. Rendering
    // only reads the completed cache, never waiting for this worker.
    if let Err(error) = std::thread::Builder::new()
        .name("recording-font".into())
        .spawn(backend::render::warm_recording_font)
    {
        tracing::warn!(?error, "Failed to start recording font warmup");
    }

    // Fix XWayland crash when too many file descriptors are open.
    let _ = rlimit::increase_nofile_limit(u64::MAX);

    // Backend selection: `VESHELL_BACKEND={drm,winit}` forces a backend, a
    // `--session` run always drives the DRM backend, and otherwise only a
    // reachable host display selects winit; a bare TTY or stale display
    // variables use the DRM backend.
    let requested = env::var("VESHELL_BACKEND").unwrap_or_default();
    let session = cli.session;
    // A display manager can start the session with the greeter's or the
    // previous session's DISPLAY/WAYLAND_DISPLAY still in the environment.
    // Only a *reachable* display makes this a nested run; a stale variable
    // must not turn a real login into a winit window on a dead server.
    let nested = !session && display_is_live();
    debug!("Selecting backend: requested={requested:?} session={session} nested={nested}");
    match select_backend(&requested, session, nested) {
        BackendKind::Drm => backend::drm_backend::run_drm_backend(),
        BackendKind::Winit => backend::winit::run_winit_backend()?,
    }

    Ok(())
}

/// The backend the process drives.
#[derive(Debug, PartialEq, Eq)]
enum BackendKind {
    Drm,
    Winit,
}

/// Resolves the backend from the explicit override, the `--session` marker and
/// the ambient display variables.
///
/// `VESHELL_BACKEND=drm|winit` always wins so the backend can be forced for
/// debugging. Otherwise a run started with `--session` is a real session and
/// must drive DRM even when the login manager leaked `DISPLAY` or
/// `WAYLAND_DISPLAY` into the service environment; without that marker, a
/// nested run (a reachable display server) uses winit and anything else falls
/// back to DRM.
fn select_backend(requested: &str, session: bool, nested: bool) -> BackendKind {
    match requested {
        "drm" => BackendKind::Drm,
        "winit" => BackendKind::Winit,
        _ if session || !nested => BackendKind::Drm,
        _ => BackendKind::Winit,
    }
}

/// Whether `DISPLAY` or `WAYLAND_DISPLAY` points at a server we can reach.
///
/// `DISPLAY`/`WAYLAND_DISPLAY` alone are not enough: display managers leak
/// them into the fresh session, often naming a socket that no longer exists.
/// Treating that as a nested run starts winit against a dead server, which
/// ends the login immediately. A live Wayland socket or a live X11 socket
/// owned by this user means the caller really is inside a graphical session.
fn display_is_live() -> bool {
    if let Ok(display) = env::var("WAYLAND_DISPLAY") {
        if wayland_display_is_live(&display) {
            return true;
        }
    }
    env::var("DISPLAY")
        .map(|display| x11_display_is_live(&display))
        .unwrap_or(false)
}

fn wayland_display_is_live(display: &str) -> bool {
    let path = if display.starts_with('/') {
        PathBuf::from(display)
    } else {
        let runtime_dir = env::var("XDG_RUNTIME_DIR")
            .ok()
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from(format!("/run/user/{}", unsafe { libc::geteuid() })));
        runtime_dir.join(display)
    };
    UnixStream::connect(path).is_ok()
}

fn x11_display_is_live(display: &str) -> bool {
    // X11 forwarding (`host:N`) is a deliberate remote display; keep the old
    // nested behaviour there. Local displays are greeter/previous-session
    // sockets, which are only usable if this user owns the live X server.
    if !display.starts_with(':') && !display.starts_with("unix:") {
        return !display.is_empty();
    }
    let rest = display
        .strip_prefix("unix:")
        .or_else(|| display.strip_prefix(':'))
        .unwrap_or_default();
    let number = rest.split('.').next().unwrap_or_default();
    if number.is_empty() || !number.bytes().all(|byte| byte.is_ascii_digit()) {
        return false;
    }
    let path = format!("/tmp/.X11-unix/X{number}");
    let owned = std::fs::metadata(&path)
        .map(|metadata| metadata.uid() == unsafe { libc::geteuid() })
        .unwrap_or(false);
    owned && UnixStream::connect(path).is_ok()
}

/// How long teardown may take before the process is forced to exit.
///
/// A normal teardown (stopping the DRM devices, the Wayland server and the
/// Flutter engine) finishes in milliseconds; the grace period only exists to
/// cover a destructor that blocks.
const SHUTDOWN_GRACE: std::time::Duration = std::time::Duration::from_secs(2);

/// Arm a watchdog that force-exits the process if teardown has not finished
/// within [`SHUTDOWN_GRACE`].
///
/// Called once the main loop has stopped, before the state (and its devices)
/// is dropped. Stopping the compositor runs every `Drop`, and some of them can
/// block indefinitely — notably `FlutterEngine::drop` →
/// `FlutterEngineShutdown`, which joins the render thread. While the process
/// is stuck it keeps DRM master and the seat: the VT stays black with no
/// input, recoverable only by a hard reboot. If teardown completes the process
/// exits before the watchdog fires; if it hangs, `_exit` closes every file
/// descriptor, which releases DRM master and the seat so the VT comes back.
pub fn arm_shutdown_watchdog() {
    let _ = std::thread::Builder::new()
        .name("shutdown-watchdog".into())
        .spawn(|| {
            std::thread::sleep(SHUTDOWN_GRACE);
            tracing::error!(
                "Compositor teardown did not finish within {:?}; forcing exit",
                SHUTDOWN_GRACE
            );
            // `_exit` skips atexit handlers and destructors, but the kernel
            // still closes every fd on exit, releasing DRM master and the
            // seat so the VT is restored.
            unsafe { libc::_exit(0) };
        });
}

pub struct FlutterState<BackendData: Backend + 'static> {
    pub flutter_engine: FlutterEngine<BackendData>,
    pub mouse_button_tracker: MouseButtonTracker,
}

pub fn send_frames_surface_tree(surface: &wl_surface::WlSurface, time: u32) {
    with_surface_tree_downward(
        surface,
        (),
        |_, _, &()| TraversalAction::DoChildren(()),
        |_surf, states, &()| {
            // the surface may not have any user_data if it is a subsurface and has not
            // yet been commited
            for callback in states
                .cached_state
                .get::<SurfaceAttributes>()
                .current()
                .frame_callbacks
                .drain(..)
            {
                callback.done(time);
            }
        },
        |_, _, &()| true,
    );
}

#[derive(Default)]
struct ClientState {
    compositor_state: CompositorClientState,
}

impl ClientData for ClientState {
    fn initialized(&self, _client_id: ClientId) {
        debug!("Client initialized {:?}", _client_id);
    }

    fn disconnected(&self, _client_id: ClientId, _reason: DisconnectReason) {
        debug!("Client disconnected {:?} {:?}", _client_id, _reason);
    }
}

#[cfg(test)]
mod backend_selection_tests {
    use super::{select_backend, BackendKind};

    #[test]
    fn explicit_override_wins() {
        assert_eq!(select_backend("drm", false, true), BackendKind::Drm);
        assert_eq!(select_backend("winit", true, false), BackendKind::Winit);
    }

    #[test]
    fn session_forces_drm_even_when_display_variables_are_set() {
        // A login manager can leak DISPLAY/WAYLAND_DISPLAY into the session
        // service; `--session` must still drive the real DRM backend.
        assert_eq!(select_backend("", true, true), BackendKind::Drm);
    }

    #[test]
    fn nested_run_uses_winit_without_session_or_override() {
        assert_eq!(select_backend("", false, true), BackendKind::Winit);
    }

    #[test]
    fn bare_run_defaults_to_drm() {
        assert_eq!(select_backend("", false, false), BackendKind::Drm);
    }
}
