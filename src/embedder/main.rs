use std::env;

use backend::Backend;
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
mod capture;
mod cursor;
mod flutter_engine;
mod focus;
mod gles_framebuffer_importer;
mod idle;
mod input_handling;
mod keyboard;
mod meta_window_state;
mod mouse_button_tracker;
mod notification;
mod portal;
mod settings;
mod state;
mod texture_swap_chain;
mod wayland;

fn main() -> Result<(), Box<dyn std::error::Error>> {
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
    // `--session` run always drives the DRM backend, and otherwise a nested
    // session (DISPLAY/WAYLAND_DISPLAY set) uses winit while a bare TTY uses
    // the DRM backend.
    let requested = env::var("VESHELL_BACKEND").unwrap_or_default();
    let session = env::args().skip(1).any(|argument| argument == "--session");
    let nested = env::var("DISPLAY").is_ok() || env::var("WAYLAND_DISPLAY").is_ok();
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
/// nested run (either variable set) uses winit and anything else falls back to
/// DRM.
fn select_backend(requested: &str, session: bool, nested: bool) -> BackendKind {
    match requested {
        "drm" => BackendKind::Drm,
        "winit" => BackendKind::Winit,
        _ if session || !nested => BackendKind::Drm,
        _ => BackendKind::Winit,
    }
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
