use smithay::{
    delegate_fractional_scale,
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
        // Here we can set the initial fractional scale
        let surface_id = get_surface_id(&surface);
        info!("new_fractional_scale: {:?}", surface_id);
        if let Some(meta_window) = self.get_meta_window(surface_id) {
            if let Some(output) = self.space.outputs().find(|output| {
                output.name() == meta_window.current_output.clone().unwrap_or("".to_string())
            }) {
                with_states(&surface, |data| {
                    with_fractional_scale(data, |fractional| {
                        fractional.set_preferred_scale(output.current_scale().fractional_scale());
                    });
                });
            }
        }
    }
}
delegate_fractional_scale!(@<BackendData: Backend + 'static> State<BackendData>);
