use std::collections::HashMap;

use serde_json::json;

use crate::flutter_engine::wayland_messages::EnvironmentVariables;
use crate::state::State;

use crate::flutter_engine::platform_channels::method_result::MethodResult;

use crate::flutter_engine::platform_channels::method_call::MethodCall;

use crate::backend::Backend;
use crate::settings::{is_valid_environment_variable_name, SESSION_DERIVED_ENVIRONMENT_VARIABLES};

/// The user-configured variables that may override the launch environment,
/// as `(name, value)` pairs.
///
/// [`SESSION_DERIVED_ENVIRONMENT_VARIABLES`] are filtered out (see above), as
/// are names a hand-edited `settings.json` could sneak past the shell's editor;
/// every other variable wins over the compositor's built-in default, which is
/// the whole point of the setting (toolkit themes, driver selection, `XDG_*`,
/// ...).
fn overridable_environment(
    variables: &HashMap<String, String>,
) -> impl Iterator<Item = (&str, &str)> {
    variables
        .iter()
        .filter(|(key, _)| {
            !SESSION_DERIVED_ENVIRONMENT_VARIABLES.contains(&key.as_str())
                && is_valid_environment_variable_name(key)
        })
        .map(|(key, value)| (key.as_str(), value.as_str()))
}

pub fn get_environment_variables<BackendData: Backend + 'static>(
    _method_call: MethodCall<serde_json::Value>,
    mut result: Box<dyn MethodResult<serde_json::Value>>,
    data: &mut State<BackendData>,
) {
    // Clone/own the dynamic values so the map below can borrow them alongside
    // the user settings without fighting the borrow checker over `data`.
    let wayland_socket_name = data.wayland_socket_name.clone();

    let xwayland_display = data
        .xwayland_state
        .as_mut()
        .map(|state| format!(":{}", state.display));

    let user_variables = data.settings_manager.get_settings().environment.variables;

    // Environment shared with application launched by the shell.
    // Tracked launches go through the systemd user manager, which has its own
    // session environment, so these values must be forwarded explicitly.
    let mut environment_variables = HashMap::from([
        ("WAYLAND_DISPLAY", wayland_socket_name.as_deref()),
        ("DISPLAY", xwayland_display.as_deref()),
        ("XDG_CURRENT_DESKTOP", Some("veshell")),
        ("XDG_SESSION_TYPE", Some("wayland")),
        ("GDK_BACKEND", Some("wayland")),
        ("QT_QPA_PLATFORM", Some("wayland")),
    ]);

    // User settings override the defaults above, except the session-derived
    // variables that describe this compositor's socket and display.
    for (key, value) in overridable_environment(&user_variables) {
        environment_variables.insert(key, Some(value));
    }

    data.flutter_engine
        .as_mut()
        .unwrap()
        .set_environment_variables(environment_variables.clone());

    result.success(Some(json!(EnvironmentVariables {
        environment_variables,
    })));
}

#[cfg(test)]
mod tests {
    use super::*;

    fn variables(pairs: &[(&str, &str)]) -> HashMap<String, String> {
        pairs
            .iter()
            .map(|(key, value)| (key.to_string(), value.to_string()))
            .collect()
    }

    #[test]
    fn user_variables_override_defaults() {
        let variables = variables(&[
            ("QT_QPA_PLATFORM", "xcb"),
            ("QT_STYLE_OVERRIDE", "Adwaita"),
            ("XDG_CURRENT_DESKTOP", "GNOME"),
        ]);
        let overrides: HashMap<&str, &str> = overridable_environment(&variables).collect();

        assert_eq!(overrides.get("QT_QPA_PLATFORM"), Some(&"xcb"));
        assert_eq!(overrides.get("QT_STYLE_OVERRIDE"), Some(&"Adwaita"));
        assert_eq!(overrides.get("XDG_CURRENT_DESKTOP"), Some(&"GNOME"));
    }

    #[test]
    fn session_derived_variables_are_never_overridden() {
        let variables = variables(&[
            ("WAYLAND_DISPLAY", "wayland-bogus"),
            ("DISPLAY", ":99"),
            ("QT_QPA_PLATFORM", "xcb"),
        ]);
        let overrides: HashMap<&str, &str> = overridable_environment(&variables).collect();

        assert!(!overrides.contains_key("WAYLAND_DISPLAY"));
        assert!(!overrides.contains_key("DISPLAY"));
        assert_eq!(overrides.get("QT_QPA_PLATFORM"), Some(&"xcb"));
    }

    #[test]
    fn malformed_names_are_ignored() {
        let variables = variables(&[
            ("VALID_NAME", "ok"),
            ("has-dash", "nope"),
            ("has space", "nope"),
            ("1LEADING", "nope"),
            ("", "nope"),
        ]);
        let overrides: HashMap<&str, &str> = overridable_environment(&variables).collect();

        assert_eq!(overrides.len(), 1);
        assert_eq!(overrides.get("VALID_NAME"), Some(&"ok"));
    }
}
