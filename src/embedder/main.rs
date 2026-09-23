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
mod capture;
mod cursor;
mod flutter_engine;
mod focus;
mod gles_framebuffer_importer;
mod input_handling;
mod keyboard;
mod meta_window_state;
mod mouse_button_tracker;
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

    // Resolve the recording counter font once, before the compositor can
    // render: the lookup shells out to `fc-match`, which must not run on
    // the render thread's first recorded frame.
    backend::render::warm_recording_font();

    // Fix XWayland crash when too many file descriptors are open.
    let _ = rlimit::increase_nofile_limit(u64::MAX);

    // Backend selection: `VESHELL_BACKEND={drm,winit,x11}` forces a backend,
    // otherwise a nested session (DISPLAY/WAYLAND_DISPLAY set) uses winit and
    // a bare TTY session uses the DRM backend.
    let requested = env::var("VESHELL_BACKEND").unwrap_or_default();
    let nested = env::var("DISPLAY").is_ok() || env::var("WAYLAND_DISPLAY").is_ok();
    match requested.as_str() {
        "drm" => backend::drm_backend::run_drm_backend(),
        "winit" => backend::winit::run_winit_backend()?,
        "x11" => backend::x11_client::run_x11_client(),
        _ if nested => backend::winit::run_winit_backend()?,
        _ => backend::drm_backend::run_drm_backend(),
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
