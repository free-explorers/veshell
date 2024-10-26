use std::{
    env,
    fs::{self, File},
    io,
    path::PathBuf,
    time::SystemTime,
};

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
use tracing_appender::rolling;
use tracing_subscriber::{fmt, layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

use crate::flutter_engine::FlutterEngine;
use crate::mouse_button_tracker::MouseButtonTracker;
use crate::state::State;

mod backend;
mod cursor;
mod flutter_engine;
mod focus;
mod gles_framebuffer_importer;
mod input_handling;
mod keyboard;
mod mouse_button_tracker;
mod state;
mod texture_swap_chain;
mod wayland;
mod xwayland;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Specify the absolute path for the logs directory
    let mut log_dir = PathBuf::from("/var/log/veshell");

    // Create the log directory if it doesn't exist
    if !fs::create_dir_all(&log_dir).is_ok() {
        let exe_path = env::current_exe().expect("Failed to get current executable path");
        let exe_dir = exe_path
            .parent()
            .expect("Failed to get executable directory");

        // Create the logs directory path
        log_dir = exe_dir.join("logs");
    }
    // Create a rolling file appender that rotates daily
    let file_appender: rolling::RollingFileAppender = rolling::daily(log_dir, "veshell.log");

    // Custom log formatting
    let format = fmt::format()
        .with_timer(fmt::time::ChronoLocal::new(String::from(
            "%Y-%m-%d %H:%M:%S%.3f",
        )))
        .compact();

    // Set up stdout layer with custom formatting
    let stdout_layer = fmt::layer()
        .event_format(format.clone())
        .with_writer(std::io::stdout)
        .with_ansi(true); // Colorful output for the terminal

    // Set up file layer with custom formatting
    let file_layer = fmt::layer()
        .event_format(format)
        .with_writer(file_appender)
        .with_ansi(false); // No colors in log file

    // Set up subscriber with both stdout and file layers
    tracing_subscriber::registry()
        .with(EnvFilter::from_default_env()) // Log level from RUST_LOG
        .with(stdout_layer)
        .with(file_layer)
        .init();

    debug!("Starting Veshell");

    // Fix XWayland crash when too many file descriptors are open.
    let _ = rlimit::increase_nofile_limit(u64::MAX);

    if env::var("DISPLAY").is_ok() || env::var("WAYLAND_DISPLAY").is_ok() {
        backend::x11_client::run_x11_client();
    } else {
        backend::drm_backend::run_drm_backend();
    }

    Ok(())
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
