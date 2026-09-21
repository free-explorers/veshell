use smithay::reexports::wayland_protocols::xdg::shell::server::xdg_toplevel;
use smithay::utils::SERIAL_COUNTER;
use smithay::wayland::compositor::with_states;
use smithay::wayland::shell::xdg;
use smithay::wayland::xwayland_shell::XWAYLAND_SHELL_ROLE;

use crate::backend::Backend;
use crate::flutter_engine::platform_channels::method_call::MethodCall;
use crate::flutter_engine::platform_channels::method_result::MethodResult;

use crate::focus::{KeyboardFocusTarget, PointerFocusTarget};
use crate::state::State;
use crate::wayland::wayland::get_surface_id;

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ActivateWindowPayload {
    pub(crate) surface_id: u64,
    pub(crate) activate: bool,
}

pub fn activate_window<BackendData: Backend + 'static>(
    method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    tracing::info!("activate_window");
    let args = method_call.arguments().unwrap().clone();
    let payload: ActivateWindowPayload = serde_json::from_value(args).unwrap();

    let pointer = data.seat.get_pointer().unwrap();
    let keyboard = data.seat.get_keyboard().unwrap();

    let serial = SERIAL_COUNTER.next_serial();

    if pointer.is_grabbed() {
        result.success(None);
        return;
    }

    // A press that landed on one of the window's own popups must not
    // re-activate/raise the parent. Raising the parent puts it above its
    // popup, so the popup's client sees the press as "outside" itself and
    // dismisses the menu on mouse-down instead of activating the item on
    // mouse-up. A window is already active whenever one of its popups is
    // shown, so the press is inert for the parent.
    if payload.activate && pointer_over_popup(data) {
        tracing::info!("activate_window: ignored, pointer is over a popup");
        result.success(None);
        return;
    }

    let Some(wl_surface) = data.surfaces.get(&payload.surface_id).cloned() else {
        result.error(
            "surface_doesnt_exist".to_string(),
            format!("Surface {} doesn't exist", payload.surface_id),
            None,
        );
        return;
    };

    let role = with_states(&wl_surface, |states| states.role);
    match role {
        Some(xdg::XDG_TOPLEVEL_ROLE) => {
            let toplevel = data.xdg_toplevels.get(&payload.surface_id).cloned();

            let Some(toplevel) = toplevel else {
                result.error(
                    "toplevel_doesnt_exist".to_string(),
                    format!("Toplevel {} doesn't exist", payload.surface_id),
                    None,
                );
                return;
            };

            toplevel.with_pending_state(|state| {
                if payload.activate {
                    state.states.set(xdg_toplevel::State::Activated);
                } else {
                    state.states.unset(xdg_toplevel::State::Activated);
                }
            });
            toplevel.send_pending_configure();

            if payload.activate {
                keyboard.set_focus(
                    data,
                    Some(KeyboardFocusTarget::WlSurface(wl_surface.clone())),
                    serial,
                );
            }
            if keyboard.current_focus() == Some(KeyboardFocusTarget::WlSurface(wl_surface))
                && !payload.activate
            {
                keyboard.set_focus(data, None, serial);
            }

            result.success(None);
        }
        Some(XWAYLAND_SHELL_ROLE) => {
            let Some(x11_surface) = data.x11_surface_per_wl_surface.get(&wl_surface).cloned()
            else {
                result.error(
                    "x11_surface_doesnt_exist".to_string(),
                    format!("X11 Surface {} doesn't exist", payload.surface_id),
                    None,
                );
                return;
            };
            x11_surface.set_activated(payload.activate).unwrap();

            if payload.activate && !x11_surface.is_override_redirect() {
                data.last_active_x11_surface = Some(x11_surface.clone());
                let _ = data
                    .xwayland_state
                    .as_mut()
                    .unwrap()
                    .xwm
                    .as_mut()
                    .unwrap()
                    .raise_window(&x11_surface);

                keyboard.set_focus(
                    data,
                    Some(KeyboardFocusTarget::X11Surface(x11_surface.clone())),
                    serial,
                );
            }
            if keyboard.current_focus() == Some(KeyboardFocusTarget::X11Surface(x11_surface))
                && !payload.activate
            {
                keyboard.set_focus(data, None, serial);
            }

            result.success(None);
        }
        _ => {
            result.error(
                "invalid_surface_role".to_string(),
                format!("Surface {} has an invalid role", payload.surface_id),
                None,
            );
            return;
        }
    }
}

/// Whether the seat pointer is currently focused on a popup: an X11
/// override-redirect window or a Wayland xdg-popup.
///
/// `PointerFocusTarget::from(&WlSurface)` always yields the `WlSurface`
/// variant, even for X11-backed surfaces, so resolve the wl_surface against
/// the X11 associations before falling back to the xdg-popup list.
fn pointer_over_popup<BackendData: Backend + 'static>(data: &State<BackendData>) -> bool {
    match data.pointer_focus.as_ref().map(|(target, _)| target) {
        Some(PointerFocusTarget::X11Surface(surface)) => surface.is_override_redirect(),
        Some(PointerFocusTarget::WlSurface(surface)) => {
            if let Some(x11_surface) = data.x11_surface_per_wl_surface.get(surface) {
                return x11_surface.is_override_redirect();
            }
            data.xdg_popups.contains_key(&get_surface_id(surface))
        }
        None => false,
    }
}
