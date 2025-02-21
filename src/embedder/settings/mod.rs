use crate::backend::Backend;
use crate::state::State;
use calloop_notify::notify::{RecursiveMode, Watcher};
use calloop_notify::NotifySource;

use serde::{Deserialize, Serialize};
use serde_json::Value;
use smithay::reexports::calloop::LoopHandle;
use std::fs::File;
use std::path::Path;
use tracing::info;

mod calloop_notify;

type SettingsCallback<BackendData> = fn(&mut State<BackendData>);
type MonitorSettingsCallback<BackendData> = fn(&mut State<BackendData>, &str);

#[derive(Serialize, Deserialize)]
pub struct KeyboardSettings {
    pub layout: String,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ThemeSettings {
    color: String,
    pub gtk_theme: String,
    pub icon_theme: String,
}

#[derive(Serialize, Deserialize)]
pub struct VeshellSettings {
    pub keyboard: KeyboardSettings,
    pub theme: ThemeSettings,
}
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq)]

pub struct MonitorResolution {
    /// horizontal coordinate
    pub width: f64,
    /// vertical coordinate
    pub height: f64,
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
#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq)]

pub struct MonitorLocation {
    /// horizontal coordinate
    pub x: f64,
    /// vertical coordinate
    pub y: f64,
}

#[derive(Serialize, Deserialize, Clone, Copy, Debug, PartialEq)]
pub struct MonitorConfiguration {
    pub mode: MonitorMode,
    pub location: MonitorLocation,
}

pub struct SettingsManager<BackendData: Backend + 'static> {
    _loop_handle: LoopHandle<'static, State<BackendData>>,
    default_settings_folder: String,
    user_settings_folder: String,
}
impl<BackendData: Backend + 'static> SettingsManager<BackendData> {
    pub fn new(
        loop_handle: LoopHandle<'static, State<BackendData>>,
        on_settings_changed: SettingsCallback<BackendData>,
        on_monitor_settings_changed: MonitorSettingsCallback<BackendData>,
    ) -> Self {
        if std::env::var("VESHELL_DEFAULT_CONFIG_DIR").is_err() {
            if let Ok(exe_path) = std::env::current_exe() {
                if let Some(exe_dir) = exe_path.parent() {
                    let config_dir = exe_dir.join("settings/default");
                    std::env::set_var("VESHELL_DEFAULT_CONFIG_DIR", config_dir);
                }
            }
        }
        let default_settings_folder = std::env::var("VESHELL_DEFAULT_CONFIG_DIR").unwrap();

        let user_settings_folder: String = std::env::var("VESHELL_CONFIG_DIR")
            .or_else(|_| {
                std::env::var("XDG_CONFIG_HOME")
                    .map(|xdg_config_home| format!("{}/veshell/settings", xdg_config_home))
                    .or_else(|_| {
                        std::env::var("HOME")
                            .map(|home| format!("{}/.config/veshell/settings", home))
                    })
            })
            .unwrap();

        if std::env::var("VESHELL_CONFIG_DIR").is_err() {
            std::env::set_var("VESHELL_CONFIG_DIR", &user_settings_folder);
        }

        let user_settings_folder_path = Path::new(&user_settings_folder);
        if !user_settings_folder_path.exists() {
            std::fs::create_dir_all(user_settings_folder_path)
                .expect("Unable to create user settings folder");
        }

        let mut notify_source = NotifySource::new().unwrap();
        notify_source
            .watch(user_settings_folder_path, RecursiveMode::Recursive)
            .unwrap();

        loop_handle
            .insert_source(notify_source, move |event, _, data| match event.kind {
                notify::EventKind::Create(_) | notify::EventKind::Modify(_) => {
                    // if path contain monitor directory, reload monitors
                    for path in event.paths {
                        // only check json files to ignore temp files
                        if path.extension().is_some() && path.extension().unwrap() == "json" {
                            info!("Settings file changed, reloading..., {:?}", event.kind);

                            if path.to_str().unwrap().contains("monitor") {
                                let monitor_name = path.file_stem().unwrap().to_str().unwrap();

                                on_monitor_settings_changed(data, monitor_name);
                            } else {
                                on_settings_changed(data);
                            }
                        }
                    }
                }
                _ => {}
            })
            .unwrap();

        Self {
            _loop_handle: loop_handle,
            default_settings_folder,
            user_settings_folder,
        }
    }

    pub fn get_settings(&self) -> VeshellSettings {
        let default_settings_path = Path::new(&self.default_settings_folder).join("settings.json");
        let default_settings_file = File::open(default_settings_path).expect("Unable to open file");
        let mut default_settings_json: Value =
            serde_json::from_reader(default_settings_file).expect("Unable to parse JSON");

        let configured_settings_path = Path::new(&self.user_settings_folder).join("settings.json");

        if configured_settings_path.exists() {
            let configured_settings_file =
                File::open(configured_settings_path).expect("Unable to open file");
            let configured_settings_json: Value =
                serde_json::from_reader(configured_settings_file).expect("Unable to parse JSON");

            merge_json(&mut default_settings_json, configured_settings_json);
        }

        serde_json::from_value(default_settings_json)
            .expect("Unable to convert JSON to VeshellSettings")
    }

    pub fn get_monitor_configuration(&self, monitor_id: &str) -> Option<MonitorConfiguration> {
        let monitor_configuration_path = Path::new(&self.user_settings_folder)
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
