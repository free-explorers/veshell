use smithay::{
    reexports::wayland_server::protocol::wl_surface::WlSurface,
    wayland::{
        compositor::with_states,
        fractional_scale::{with_fractional_scale, FractionalScaleHandler},
    },
};
use tracing::info;

use crate::{backend::Backend, state::State, wayland::wayland::get_surface_id};

impl<BackendData: Backend + 'static> FractionalScaleHandler for State<BackendData> {
    fn new_fractional_scale(&mut self, surface: WlSurface) {
        let surface_id = get_surface_id(&surface);
        let Some(meta_window) = self.get_meta_window(surface_id) else {
            info!(
                "new_fractional_scale: no meta window yet for {:?}",
                surface_id
            );
            return;
        };

        // `MetaWindow::scale_ratio` owns the client's preferred scale. When the
        // shell has already placed the window, use its output's live scale;
        // otherwise fall back to the creation-time default (the output under
        // the pointer, else the first output). This is the first time the
        // window's preferred scale is sent, so log it to make the later
        // `UpdateScaleRatio` round-trip observable.
        let scale = meta_window
            .current_output
            .as_deref()
            .and_then(|name| self.output_scale_for_name(name))
            .unwrap_or(meta_window.scale_ratio);
        info!(
            target: "veshell::geometry",
            surface_id,
            meta_window_id = %meta_window.id,
            current_output = ?meta_window.current_output,
            preferred_scale = scale,
            "Setting client preferred fractional scale"
        );
        with_states(&surface, |data| {
            with_fractional_scale(data, |fractional| {
                fractional.set_preferred_scale(scale);
            });
        });
    }
}
