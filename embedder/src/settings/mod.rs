use std::{fs::File, path::PathBuf};
use crate::backend::Backend;
use calloop_notify::notify::{RecursiveMode, Watcher};
use calloop_notify::NotifySource;
use serde::{Serialize, Deserialize};
use serde_json::Value;
use smithay::reexports::calloop::LoopHandle;
use tracing::info;
use std::path::Path;
use crate::state::State;
use smithay::reexports::calloop::EventLoop;

mod calloop_notify;

type SettingsCallback<BackendData> = fn(&mut State<BackendData>);

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

pub struct SettingsManager<BackendData: Backend + 'static> {
    loop_handle: LoopHandle<'static, State<BackendData>>,
    default_settings_folder: String,
    user_settings_folder: String,
}
impl<BackendData: Backend + 'static> SettingsManager<BackendData>  {
    pub fn new(loop_handle: LoopHandle<'static, State<BackendData>>, on_settings_changed: SettingsCallback<BackendData>) -> Self {
        if std::env::var("VESHELL_DEFAULT_CONFIG_DIR").is_err() {
            if let Ok(exe_path) = std::env::current_exe() {
                if let Some(exe_dir) = exe_path.parent() {
                    let config_dir = exe_dir.join("settings/default");
                    std::env::set_var("VESHELL_DEFAULT_CONFIG_DIR", config_dir);
                }
            }
        }
        let default_settings_folder = std::env::var("VESHELL_DEFAULT_CONFIG_DIR").unwrap();
        let user_settings_folder: String = std::env::var("VESHELL_CONFIG_DIR").or_else(|_| {
            std::env::var("XDG_CONFIG_HOME").map(|xdg_config_home| {
                format!("{}/veshell/settings", xdg_config_home)
            }).or_else(|_| {
                std::env::var("HOME").map(|home| {
                    format!("{}/.config/veshell/settings", home)
                })
            })
        }).unwrap();

        let user_settings_folder_path = Path::new(&user_settings_folder);
        if !user_settings_folder_path.exists() {
            std::fs::create_dir_all(user_settings_folder_path).expect("Unable to create user settings folder");
        }

        let mut notify_source = NotifySource::new().unwrap();
        notify_source.watch(user_settings_folder_path, RecursiveMode::Recursive).unwrap();
        
        loop_handle
        .insert_source(notify_source, move |event, _, data| {
            match event.kind {
                notify::EventKind::Create(_) | notify::EventKind::Modify(_) => {
                    info!("Settings file changed, reloading...");
                    on_settings_changed(data);
                    // TODO: Reload settings
                }
                _ => {}
            }
        })
        .unwrap();

        Self { 
            loop_handle,
            default_settings_folder,
            user_settings_folder,
        }
    }

    pub fn get_settings(&self) -> VeshellSettings {
        let default_settings_path = Path::new(&self.default_settings_folder).join("settings.json");
        let default_settings_file = File::open(default_settings_path).expect("Unable to open file");
        let mut default_settings_json: Value = serde_json::from_reader(default_settings_file).expect("Unable to parse JSON");
    
        let configured_settings_path = Path::new(&self.user_settings_folder).join("settings.json");
    
        if configured_settings_path.exists() {
            let configured_settings_file = File::open(configured_settings_path).expect("Unable to open file");
            let configured_settings_json: Value = serde_json::from_reader(configured_settings_file).expect("Unable to parse JSON");
    
            merge_json(&mut default_settings_json, configured_settings_json);
        }
    
        serde_json::from_value(default_settings_json).expect("Unable to convert JSON to VeshellSettings")
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