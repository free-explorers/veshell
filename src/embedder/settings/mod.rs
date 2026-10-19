use crate::backend::Backend;
use crate::state::State;
use calloop_notify::notify::{RecursiveMode, Watcher};
use calloop_notify::NotifySource;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use smithay::output::Mode;
use smithay::reexports::calloop::LoopHandle;
use smithay::utils::{Logical, Physical, Point, Size, Transform};
use std::collections::HashMap;
use std::fs::File;
use std::path::Path;
use tracing::info;

mod calloop_notify;

type SettingsCallback<BackendData> = fn(&mut State<BackendData>);
type MonitorSettingsCallback<BackendData> = fn(&mut State<BackendData>, &str);

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]

pub struct KeyboardSettings {
    pub layout: String,
    pub swap_alt_and_win: bool,
    /// What the Caps Lock key does, implemented as an xkb option.
    #[serde(default, deserialize_with = "deserialize_caps_lock_behavior")]
    pub caps_lock: CapsLockBehavior,
    /// Whether holding a key repeats it.
    #[serde(default = "default_keyboard_repeat")]
    pub repeat: bool,
    /// Milliseconds a key must be held before repeating starts.
    #[serde(
        default = "default_keyboard_repeat_delay_ms",
        deserialize_with = "deserialize_u64_saturating"
    )]
    pub repeat_delay_ms: u64,
    /// Repeats per second while a key is held. `0` disables repeating.
    #[serde(
        default = "default_keyboard_repeat_rate",
        deserialize_with = "deserialize_u64_saturating"
    )]
    pub repeat_rate: u64,
}

impl KeyboardSettings {
    /// The repeat rate to advertise and run, honouring the on/off switch.
    ///
    /// A disabled repeat is a rate of `0` — the `wl_keyboard.repeat_info`
    /// convention — which also turns off the shell's own repeater.
    pub fn effective_repeat_rate(&self) -> u64 {
        if self.repeat {
            self.repeat_rate
        } else {
            0
        }
    }
}

/// What the Caps Lock key does.
///
/// Unlike [`KeyboardSettings::swap_alt_and_win`] — an event-level keycode swap —
/// this is applied through an xkb *option* on the seat keymap, so the remap is
/// one-way and reaches both the shell and forwarded clients.
#[derive(Serialize, Clone, Copy, Debug, Default, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum CapsLockBehavior {
    /// Caps Lock keeps its normal behavior.
    #[default]
    Default,
    /// Caps Lock acts as an additional Control (`ctrl:nocaps`).
    Control,
    /// Caps Lock acts as Escape (`caps:escape`).
    Escape,
    /// Caps Lock and Escape are swapped (`caps:swapescape`).
    Swapescape,
    /// Caps Lock is disabled (`caps:none`).
    Disabled,
}

impl CapsLockBehavior {
    /// The xkb option that implements this behavior, or `None` for the default.
    pub fn xkb_option(self) -> Option<&'static str> {
        match self {
            Self::Default => None,
            Self::Control => Some("ctrl:nocaps"),
            Self::Escape => Some("caps:escape"),
            Self::Swapescape => Some("caps:swapescape"),
            Self::Disabled => Some("caps:none"),
        }
    }
}

/// Reads a [`CapsLockBehavior`], falling back to the default for an unknown
/// value so a hand-edited `settings.json` cannot take the settings load down.
fn deserialize_caps_lock_behavior<'de, D>(deserializer: D) -> Result<CapsLockBehavior, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = String::deserialize(deserializer)?;
    Ok(match value.as_str() {
        "control" => CapsLockBehavior::Control,
        "escape" => CapsLockBehavior::Escape,
        "swapescape" => CapsLockBehavior::Swapescape,
        "disabled" => CapsLockBehavior::Disabled,
        _ => CapsLockBehavior::Default,
    })
}

/// Reads a non-negative integer, clamping negative values to `0`.
///
/// The settings UI's number field can produce a negative value; a raw `u64`
/// would otherwise fail deserialization and take the whole settings load (and
/// the compositor) down with it.
fn deserialize_u64_saturating<'de, D>(deserializer: D) -> Result<u64, D::Error>
where
    D: serde::Deserializer<'de>,
{
    Ok(i64::deserialize(deserializer)?.max(0) as u64)
}

fn default_keyboard_repeat() -> bool {
    true
}

fn default_keyboard_repeat_delay_ms() -> u64 {
    500
}

fn default_keyboard_repeat_rate() -> u64 {
    30
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]

pub struct MouseAndTouchpadSettings {
    /// Reverse the scroll direction on mice.
    ///
    /// Defaults off, matching libinput, GNOME, Windows and KDE: a mouse wheel
    /// scrolls content in the traditional direction.
    #[serde(default)]
    pub mouse_natural_scrolling: bool,
    /// Reverse the two-finger scroll direction on touchpads.
    ///
    /// Defaults on, matching GNOME and libinput's Apple-touchpad default.
    #[serde(default = "default_touchpad_natural_scrolling")]
    pub touchpad_natural_scrolling: bool,
    /// Multiplier applied to the mouse wheel's scroll distance. `1.0` is the
    /// neutral default.
    ///
    /// The shell turns it into `DEFAULT_WHEEL_SCROLL_PIXELS_PER_DETENT` logical
    /// pixels per detent and forwards the same factor to client apps (whose
    /// scroll units are toolkit-relative, so only a factor can reach them).
    /// This mirrors the `scroll_factor` knobs in KWin, Hyprland and labwc.
    #[serde(default = "default_wheel_scroll_factor")]
    pub wheel_scroll_factor: f64,
}

fn default_touchpad_natural_scrolling() -> bool {
    true
}

/// Shipped default for the shell's wheel step, in logical pixels per detent.
///
/// 53 is GTK+'s wheel step (copied by Chromium's X11 code and Flutter's GTK
/// embedder). `mouseAndTouchpad.wheelScrollFactor` scales it.
pub const DEFAULT_WHEEL_SCROLL_PIXELS_PER_DETENT: u32 = 53;

fn default_wheel_scroll_factor() -> f64 {
    1.0
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ThemeSettings {
    color: String,
    /// Kept optional: the packaged defaults no longer hardcode a theme, and the
    /// shell resolves the best installed one at launch.
    #[serde(default)]
    pub gtk_theme: String,
    #[serde(default)]
    pub icon_theme: String,
}

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum AutomaticPowerAction {
    Disabled,
    Suspend,
    Hibernate,
    /// Ask logind to suspend, then hibernate after its configured delay.
    SuspendThenHibernate,
}

fn deserialize_automatic_power_action<'de, D>(
    deserializer: D,
) -> Result<AutomaticPowerAction, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let value = String::deserialize(deserializer)?;
    Ok(match value.as_str() {
        "suspend" => AutomaticPowerAction::Suspend,
        "hibernate" => AutomaticPowerAction::Hibernate,
        "suspendThenHibernate" => AutomaticPowerAction::SuspendThenHibernate,
        _ => AutomaticPowerAction::Disabled,
    })
}

impl Default for AutomaticPowerAction {
    fn default() -> Self {
        Self::SuspendThenHibernate
    }
}

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct IdleSettings {
    /// Seconds of inactivity before the dim fade starts. `0` disables dimming.
    pub dim_timeout_seconds: u32,
    /// Seconds of inactivity before the outputs are powered down.
    /// `0` disables blanking.
    pub blank_timeout_seconds: u32,
    /// Fade duration in seconds, from nothing to fully black.
    pub fade_seconds: f32,
    /// Automatic power action after the machine has remained idle.
    #[serde(deserialize_with = "deserialize_automatic_power_action")]
    pub automatic_power_action: AutomaticPowerAction,
    /// Seconds idle before the automatic power action; `0` disables it.
    pub automatic_power_timeout_seconds: u32,
}
impl Default for IdleSettings {
    fn default() -> Self {
        Self {
            dim_timeout_seconds: 300,
            blank_timeout_seconds: 600,
            fade_seconds: 3.0,
            automatic_power_action: AutomaticPowerAction::default(),
            automatic_power_timeout_seconds: 600,
        }
    }
}

/// User-configured environment variables.
///
/// They are merged into the launch environment reported to the shell
/// (`get_environment_variables`), applied to the compositor's own process
/// environment so spawned children inherit them, and imported into the
/// session's systemd user manager and D-Bus activation environment (so portals,
/// xdg-autostart units and other launchers see them). The shipped default is an
/// empty map.
#[derive(Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct EnvironmentSettings {
    /// Variable names to values. Names follow `[A-Za-z_][A-Za-z0-9_]*`.
    #[serde(default)]
    pub variables: HashMap<String, String>,
}

/// Environment variables the compositor owns because they describe the live
/// session: the Wayland socket and the X11 display.
///
/// User settings must never override them — doing so would leave every launched
/// application unable to connect — so both the launch environment and the
/// compositor's own process environment keep the session-derived values.
pub const SESSION_DERIVED_ENVIRONMENT_VARIABLES: [&str; 2] = ["WAYLAND_DISPLAY", "DISPLAY"];

/// Whether `name` is a portable POSIX environment variable name
/// (`[A-Za-z_][A-Za-z0-9_]*`).
///
/// The shell validates names in its editor, but a hand-edited `settings.json`
/// bypasses it, so the compositor re-checks before forwarding a name to the
/// launch environment or to `systemd`/`dbus`.
pub fn is_valid_environment_variable_name(name: &str) -> bool {
    let mut characters = name.chars();
    match characters.next() {
        Some(first) if first == '_' || first.is_ascii_alphabetic() => {}
        _ => return false,
    }
    characters.all(|character| character == '_' || character.is_ascii_alphanumeric())
}

impl EnvironmentSettings {
    /// The valid user variable names, skipping anything malformed.
    pub fn variable_names(&self) -> impl Iterator<Item = &str> {
        self.variables
            .keys()
            .filter(|name| is_valid_environment_variable_name(name))
            .map(String::as_str)
    }
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VeshellSettings {
    pub keyboard: KeyboardSettings,
    pub mouse_and_touchpad: MouseAndTouchpadSettings,
    pub theme: ThemeSettings,
    #[serde(default)]
    pub idle: IdleSettings,
    #[serde(default)]
    pub environment: EnvironmentSettings,
}
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct MonitorResolution {
    /// horizontal coordinate
    pub width: i32,
    /// vertical coordinate
    pub height: i32,
}
impl From<MonitorResolution> for Size<i32, Physical> {
    fn from(resolution: MonitorResolution) -> Self {
        (resolution.width, resolution.height).into()
    }
}

impl From<Size<i32, Physical>> for MonitorResolution {
    fn from(size: Size<i32, Physical>) -> Self {
        MonitorResolution {
            width: size.w,
            height: size.h,
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct MonitorMode {
    /// The size of the mode, in pixels
    pub size: MonitorResolution,
    /// The refresh rate in millihertz
    ///
    /// `1000` is one fps (frame per second), `2000` is 2 fps, etc...
    pub refresh_rate: i32,
}
impl From<Mode> for MonitorMode {
    fn from(mode: Mode) -> Self {
        MonitorMode {
            size: MonitorResolution::from(mode.size),
            refresh_rate: mode.refresh,
        }
    }
}
impl From<MonitorMode> for Mode {
    fn from(monitor_mode: MonitorMode) -> Self {
        Mode {
            size: monitor_mode.size.into(), // Assuming you can convert between these types
            refresh: monitor_mode.refresh_rate,
        }
    }
}

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq)]
pub struct MonitorLocation {
    /// horizontal coordinate
    pub x: i32,
    /// vertical coordinate
    pub y: i32,
}
impl From<MonitorLocation> for Point<i32, Logical> {
    fn from(location: MonitorLocation) -> Self {
        (location.x, location.y).into()
    }
}

impl From<Point<i32, Logical>> for MonitorLocation {
    fn from(point: Point<i32, Logical>) -> Self {
        MonitorLocation {
            x: point.x,
            y: point.y,
        }
    }
}

/// User-facing display transform of one monitor.
///
/// Exposes the full set of Smithay output transforms. `Normal` is the panel's
/// native orientation; `Rotate90/180/270` turn it clockwise and the `Flipped*`
/// variants additionally mirror it. The transform is applied to the live
/// `Output`; the Flutter view is sized to the transformed size, so the
/// 90/270 variants (a quarter turn) lay out a portrait surface while the
/// others keep the mode's dimensions.
#[derive(Serialize, Deserialize, Default, Clone, Copy, Debug, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum MonitorTransform {
    #[default]
    Normal,
    Rotate90,
    Rotate180,
    Rotate270,
    Flipped,
    Flipped90,
    Flipped180,
    Flipped270,
}

impl From<MonitorTransform> for Transform {
    fn from(transform: MonitorTransform) -> Self {
        match transform {
            MonitorTransform::Normal => Transform::Normal,
            MonitorTransform::Rotate90 => Transform::_90,
            MonitorTransform::Rotate180 => Transform::_180,
            MonitorTransform::Rotate270 => Transform::_270,
            MonitorTransform::Flipped => Transform::Flipped,
            MonitorTransform::Flipped90 => Transform::Flipped90,
            MonitorTransform::Flipped180 => Transform::Flipped180,
            MonitorTransform::Flipped270 => Transform::Flipped270,
        }
    }
}

/// Desired geometry for one monitor, persisted as `monitor/<connector>.json`.
///
/// This is the single Rust-side consumer of the desired-geometry store written
/// by Dart's `MonitorSettingState`. Actual hardware state lives in the live
/// `Output`; see `docs/specifications/monitor.md` (section "State ownership").
///
/// New fields are `#[serde(default)]` so files written before the field existed
/// keep deserializing: `transform` defaults to normal and `mirror_of` defaults
/// to "not mirrored" (a regular display).
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct MonitorConfiguration {
    pub mode: MonitorMode,
    pub location: MonitorLocation,
    pub fractionnal_scale: f64,
    #[serde(default)]
    pub transform: MonitorTransform,
    /// Connector name of the monitor this one mirrors, if any. The mirror is
    /// best-effort: when the target is absent (or is itself mirroring) the
    /// monitor falls back to a regular display.
    #[serde(default)]
    pub mirror_of: Option<String>,
}

pub struct SettingsManager<BackendData: Backend + 'static> {
    _loop_handle: LoopHandle<'static, State<BackendData>>,
    default_settings_folder: String,
    config_folder_path: String,
}
impl<BackendData: Backend + 'static> SettingsManager<BackendData> {
    pub fn new(
        loop_handle: LoopHandle<'static, State<BackendData>>,
        on_settings_changed: SettingsCallback<BackendData>,
        on_monitor_settings_changed: MonitorSettingsCallback<BackendData>,
    ) -> Self {
        let mut default_settings_folder = option_env!("VESHELL_DEFAULT_CONFIG_DIR")
            .unwrap_or("/usr/share/veshell/settings/default")
            .to_owned();

        if let Ok(executable_path) = std::env::current_exe() {
            if option_env!("VESHELL_DEFAULT_CONFIG_DIR").is_none()
                && executable_path.starts_with("/usr/local/bin")
            {
                default_settings_folder = format!("/usr/local/share/veshell/settings/default");
            }
        }

        if std::env::var("VESHELL_DEFAULT_CONFIG_DIR").is_err() {
            std::env::set_var(
                "VESHELL_DEFAULT_CONFIG_DIR",
                default_settings_folder.clone(),
            );
        } else {
            default_settings_folder = std::env::var("VESHELL_DEFAULT_CONFIG_DIR").unwrap();
        }

        let config_folder_path = std::env::var("VESHELL_CONFIG_DIR")
            .or_else(|_| {
                std::env::var("XDG_CONFIG_HOME")
                    .map(|xdg_config_home| format!("{}/veshell/", xdg_config_home))
                    .or_else(|_| {
                        std::env::var("HOME").map(|home| format!("{}/.config/veshell/", home))
                    })
            })
            .unwrap();

        if std::env::var("VESHELL_CONFIG_DIR").is_err() {
            std::env::set_var("VESHELL_CONFIG_DIR", &config_folder_path);
        }
        let config_folder = Path::new(&config_folder_path);

        if !config_folder.exists() {
            std::fs::create_dir_all(config_folder.clone())
                .expect("Unable to create user settings folder");
        }

        let mut config_source = NotifySource::new().unwrap();
        config_source
            .watch(config_folder, RecursiveMode::NonRecursive)
            .unwrap();

        let settings_path = config_folder.join("settings.json");

        let monitor_path = config_folder.join("monitor");

        if monitor_path.exists() {
            watch_monitors_changes(
                config_folder_path.clone(),
                loop_handle.clone(),
                on_monitor_settings_changed,
            );
        } else {
            std::fs::create_dir_all(monitor_path.clone())
                .expect("Unable to create user settings folder");
        }

        loop_handle
            .clone()
            .insert_source(config_source, move |event, _, data| match event.kind {
                notify::EventKind::Create(_) | notify::EventKind::Modify(_) => {
                    if event.paths.contains(&settings_path) {
                        on_settings_changed(data);
                    }
                    if event.paths.contains(&monitor_path) {
                        watch_monitors_changes(
                            data.settings_manager.config_folder_path.clone(),
                            data.loop_handle.clone(),
                            on_monitor_settings_changed,
                        );
                    }
                }
                _ => {}
            })
            .unwrap();

        Self {
            _loop_handle: loop_handle.clone(),
            default_settings_folder,
            config_folder_path: config_folder.to_str().unwrap().to_string(),
        }
    }

    pub fn get_settings(&self) -> VeshellSettings {
        let default_settings_path = Path::new(&self.default_settings_folder).join("settings.json");
        info!("Loading settings from {}", default_settings_path.display());
        let default_settings_file = File::open(default_settings_path).expect("Unable to open file");
        let mut settings_json: Value =
            serde_json::from_reader(default_settings_file).expect("Unable to parse JSON");

        let configured_settings_path = Path::new(&self.config_folder_path).join("settings.json");

        if configured_settings_path.exists() {
            let configured_settings_file =
                File::open(configured_settings_path).expect("Unable to open file");
            let configured_settings_json: Value =
                serde_json::from_reader(configured_settings_file).expect("Unable to parse JSON");

            merge_json(&mut settings_json, configured_settings_json);
        }

        serde_json::from_value(settings_json).expect("Unable to convert JSON to VeshellSettings")
    }

    /// Reads the desired geometry written by Dart `MonitorSettingState`.
    ///
    /// Single consumer of `monitor/<connector>.json`; the returned
    /// [`MonitorConfiguration`] is applied best-effort and may be rejected by
    /// the hardware. See `docs/specifications/monitor.md` (section "State
    /// ownership").
    pub fn get_monitor_configuration(&self, monitor_id: &str) -> Option<MonitorConfiguration> {
        let monitor_configuration_path = Path::new(&self.config_folder_path)
            .join("monitor")
            .join(format!("{}.json", monitor_id));
        if !monitor_configuration_path.exists() {
            return None;
        }
        let monitor_configuration_file =
            File::open(monitor_configuration_path.clone()).expect("Unable to open file");
        // print content of file
        info!(
            "{}",
            std::fs::read_to_string(monitor_configuration_path.clone())
                .expect("Unable to read file")
        );
        match serde_json::from_reader(monitor_configuration_file) {
            Ok(config) => Some(config),
            Err(e) => {
                info!("Failed to parse JSON: {}", e);
                None
            }
        }
    }
}

fn merge_json(target: &mut Value, source: Value) {
    match (target, source) {
        (Value::Object(ref mut t_obj), Value::Object(s_obj)) => {
            for (key, value) in s_obj {
                if let Some(t_value) = t_obj.get_mut(&key) {
                    merge_json(t_value, value);
                } else {
                    t_obj.insert(key, value);
                }
            }
        }
        (target, source) => {
            *target = source;
        }
    }
}

fn watch_monitors_changes<BackendData: Backend + 'static>(
    config_folder_path: String,
    loop_handle: LoopHandle<'static, State<BackendData>>,
    on_monitor_settings_changed: MonitorSettingsCallback<BackendData>,
) {
    let config_folder = Path::new(&config_folder_path);
    let monitor_path = config_folder.join("monitor");
    if monitor_path.exists() {
        let mut monitor_source = NotifySource::new().unwrap();
        monitor_source
            .watch(&monitor_path, RecursiveMode::Recursive)
            .unwrap();
        loop_handle
            .insert_source(monitor_source, move |event, _, data| match event.kind {
                notify::EventKind::Create(_) | notify::EventKind::Modify(_) => {
                    for path in event.paths {
                        // only check json files to ignore temp files
                        if path.extension().is_some() && path.extension().unwrap() == "json" {
                            info!("Settings file changed, reloading..., {:?}", event.kind);
                            let monitor_name = path.file_stem().unwrap().to_str().unwrap();
                            on_monitor_settings_changed(data, monitor_name);
                        }
                    }
                }
                _ => {}
            })
            .unwrap();
    }
}

#[cfg(test)]
mod monitor_configuration_tests {
    use super::*;

    /// A configuration written before transform / mirror existed must keep
    /// deserializing, defaulting to a normal regular display.
    #[test]
    fn legacy_monitor_configuration_defaults_new_fields() {
        let json = r#"{
            "mode": { "size": { "width": 1920, "height": 1080 }, "refreshRate": 60000 },
            "fractionnalScale": 1.5,
            "location": { "x": 10, "y": 20 }
        }"#;

        let config: MonitorConfiguration = serde_json::from_str(json).unwrap();

        assert_eq!(config.transform, MonitorTransform::Normal);
        assert_eq!(config.mirror_of, None);
        assert_eq!(config.fractionnal_scale, 1.5);
    }

    #[test]
    fn transform_maps_to_output_transform() {
        assert_eq!(Transform::from(MonitorTransform::Normal), Transform::Normal);
        assert_eq!(Transform::from(MonitorTransform::Rotate90), Transform::_90);
        assert_eq!(
            Transform::from(MonitorTransform::Rotate180),
            Transform::_180
        );
        assert_eq!(
            Transform::from(MonitorTransform::Rotate270),
            Transform::_270
        );
        assert_eq!(
            Transform::from(MonitorTransform::Flipped),
            Transform::Flipped
        );
        assert_eq!(
            Transform::from(MonitorTransform::Flipped90),
            Transform::Flipped90
        );
        assert_eq!(
            Transform::from(MonitorTransform::Flipped180),
            Transform::Flipped180
        );
        assert_eq!(
            Transform::from(MonitorTransform::Flipped270),
            Transform::Flipped270
        );
    }

    #[test]
    fn monitor_configuration_round_trips_new_fields() {
        let config = MonitorConfiguration {
            mode: MonitorMode {
                size: MonitorResolution {
                    width: 1080,
                    height: 1920,
                },
                refresh_rate: 60_000,
            },
            location: MonitorLocation { x: 0, y: 0 },
            fractionnal_scale: 1.0,
            transform: MonitorTransform::Rotate90,
            mirror_of: Some("DP-2".to_string()),
        };

        let value = serde_json::to_value(config).unwrap();
        assert_eq!(value["transform"], "rotate90");
        assert_eq!(value["mirrorOf"], "DP-2");

        let decoded: MonitorConfiguration = serde_json::from_value(value).unwrap();
        assert_eq!(decoded.transform, MonitorTransform::Rotate90);
        assert_eq!(decoded.mirror_of.as_deref(), Some("DP-2"));
    }
}

#[cfg(test)]
mod keyboard_settings_tests {
    use super::*;

    /// A settings file written before the repeat fields existed must keep
    /// deserializing, defaulting to repetition enabled at 500 ms / 30 cps.
    #[test]
    fn legacy_keyboard_settings_default_repeat_fields() {
        let settings: KeyboardSettings =
            serde_json::from_str(r#"{"layout":"us","swapAltAndWin":false}"#).unwrap();
        assert!(settings.repeat);
        assert_eq!(settings.repeat_delay_ms, 500);
        assert_eq!(settings.repeat_rate, 30);
        assert_eq!(settings.effective_repeat_rate(), 30);
    }

    #[test]
    fn disabled_repeat_reports_a_zero_rate() {
        let settings: KeyboardSettings = serde_json::from_str(
            r#"{"layout":"us","swapAltAndWin":false,"repeat":false,"repeatRate":45}"#,
        )
        .unwrap();
        // The configured rate is remembered, but the effective one is disabled.
        assert_eq!(settings.repeat_rate, 45);
        assert_eq!(settings.effective_repeat_rate(), 0);
    }

    #[test]
    fn negative_repeat_values_are_clamped() {
        let settings: KeyboardSettings = serde_json::from_str(
            r#"{"layout":"us","swapAltAndWin":false,"repeatDelayMs":-10,"repeatRate":-1}"#,
        )
        .unwrap();
        assert_eq!(settings.repeat_delay_ms, 0);
        assert_eq!(settings.repeat_rate, 0);
    }

    /// A settings file written before the field existed keeps deserializing.
    #[test]
    fn caps_lock_defaults_when_missing() {
        let settings: KeyboardSettings =
            serde_json::from_str(r#"{"layout":"us","swapAltAndWin":false}"#).unwrap();
        assert_eq!(settings.caps_lock, CapsLockBehavior::Default);
        assert_eq!(settings.caps_lock.xkb_option(), None);
    }

    #[test]
    fn caps_lock_reads_each_behavior() {
        for (value, behavior, option) in [
            ("default", CapsLockBehavior::Default, None),
            ("control", CapsLockBehavior::Control, Some("ctrl:nocaps")),
            ("escape", CapsLockBehavior::Escape, Some("caps:escape")),
            (
                "swapescape",
                CapsLockBehavior::Swapescape,
                Some("caps:swapescape"),
            ),
            ("disabled", CapsLockBehavior::Disabled, Some("caps:none")),
        ] {
            let settings: KeyboardSettings = serde_json::from_str(&format!(
                r#"{{"layout":"us","swapAltAndWin":false,"capsLock":"{value}"}}"#
            ))
            .unwrap();
            assert_eq!(settings.caps_lock, behavior);
            assert_eq!(settings.caps_lock.xkb_option(), option);
        }
    }

    #[test]
    fn unknown_caps_lock_falls_back_to_the_default() {
        let settings: KeyboardSettings = serde_json::from_str(
            r#"{"layout":"us","swapAltAndWin":false,"capsLock":"nonsense"}"#,
        )
        .unwrap();
        assert_eq!(settings.caps_lock, CapsLockBehavior::Default);
    }
}

#[cfg(test)]
mod mouse_and_touchpad_settings_tests {
    use super::*;

    /// A settings file written before the split kept a single
    /// `naturalScrolling` flag. It is dropped when merged with the shipped
    /// defaults, and the per-device split falls back to mouse off / touchpad on.
    #[test]
    fn legacy_natural_scrolling_key_falls_back_to_the_split_defaults() {
        let settings: MouseAndTouchpadSettings =
            serde_json::from_str(r#"{"naturalScrolling":true}"#).unwrap();

        assert!(!settings.mouse_natural_scrolling);
        assert!(settings.touchpad_natural_scrolling);
        assert_eq!(settings.wheel_scroll_factor, 1.0);
    }

    #[test]
    fn wheel_scroll_factor_defaults_to_one_and_reads_custom_values() {
        let defaulted: MouseAndTouchpadSettings =
            serde_json::from_str(r#"{"mouseNaturalScrolling":false}"#).unwrap();
        assert_eq!(defaulted.wheel_scroll_factor, 1.0);

        let custom: MouseAndTouchpadSettings =
            serde_json::from_str(r#"{"wheelScrollFactor":1.5}"#).unwrap();
        assert_eq!(custom.wheel_scroll_factor, 1.5);
    }
}
