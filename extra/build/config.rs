use std::env;
use std::fmt::{Display, Formatter};
use std::path::{Path, PathBuf};
use std::str::FromStr;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum FlutterEngineBuild {
    Debug,
    Profile,
    Release,
}

impl FromStr for FlutterEngineBuild {
    type Err = String;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "debug" => Ok(Self::Debug),
            "profile" => Ok(Self::Profile),
            "release" => Ok(Self::Release),
            _ => Err(format!(
                "Unknown Flutter mode {value:?}; set VESHELL_FLUTTER_MODE to debug, profile, or release."
            )),
        }
    }
}

impl Display for FlutterEngineBuild {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::Debug => "debug",
            Self::Profile => "profile",
            Self::Release => "release",
        })
    }
}

pub struct BuildConfig {
    pub mode: FlutterEngineBuild,
    pub shell: Option<PathBuf>,
    pub engine: Option<PathBuf>,
    pub lib_dir: Option<PathBuf>,
    pub data_dir: Option<PathBuf>,
    pub default_config_dir: Option<PathBuf>,
}

impl BuildConfig {
    pub fn from_env() -> Result<Self, String> {
        let profile = env::var("OUT_DIR")
            .ok()
            .and_then(|out| output_profile(Path::new(&out)).map(str::to_owned))
            .or_else(|| env::var("PROFILE").ok())
            .unwrap_or_else(|| "debug".to_owned());
        let mode = env::var("VESHELL_FLUTTER_MODE").unwrap_or(profile);
        let path = |name| env::var_os(name).map(PathBuf::from);
        let mut config = Self {
            mode: mode.parse()?,
            shell: path("VESHELL_PREBUILT_SHELL"),
            engine: path("VESHELL_ENGINE_DIR"),
            lib_dir: path("VESHELL_LIB_DIR"),
            data_dir: path("VESHELL_DATA_DIR"),
            default_config_dir: path("VESHELL_DEFAULT_CONFIG_DIR"),
        };
        config.validate()?;
        if let Some(shell) = &config.shell {
            config.shell = Some(shell.canonicalize().map_err(|e| e.to_string())?);
        }
        if let Some(engine) = &config.engine {
            config.engine = Some(engine.canonicalize().map_err(|e| e.to_string())?);
        }
        Ok(config)
    }

    pub fn validate(&self) -> Result<(), String> {
        if self.shell.is_some() != self.engine.is_some() {
            return Err("External builds require both VESHELL_PREBUILT_SHELL and VESHELL_ENGINE_DIR; the shell must use that engine's matching AOT compiler.".to_owned());
        }
        if self.lib_dir.is_some() != self.data_dir.is_some() {
            return Err("Set VESHELL_LIB_DIR and VESHELL_DATA_DIR together, using final installation paths without DESTDIR.".to_owned());
        }
        for path in [&self.lib_dir, &self.data_dir, &self.default_config_dir]
            .into_iter()
            .flatten()
        {
            if !path.is_absolute() {
                return Err(format!(
                    "Runtime installation path must be absolute: {}",
                    path.display()
                ));
            }
        }
        if let (Some(shell), Some(engine)) = (&self.shell, &self.engine) {
            let app = if self.mode == FlutterEngineBuild::Debug {
                "data/flutter_assets/kernel_blob.bin"
            } else {
                "lib/libapp.so"
            };
            for path in [
                shell.join(app),
                shell.join("data/icudtl.dat"),
                engine.join("flutter_embedder.h"),
                engine
                    .join(self.mode.to_string())
                    .join("libflutter_engine.so"),
            ] {
                if !path.is_file() || path.metadata().map_err(|e| e.to_string())?.len() == 0 {
                    return Err(format!(
                        "Missing or empty external build input: {}",
                        path.display()
                    ));
                }
            }
            if !shell.join("data/flutter_assets").is_dir() {
                return Err("External shell is missing data/flutter_assets.".to_owned());
            }
        }
        Ok(())
    }
}

fn output_profile(out: &Path) -> Option<&str> {
    if out.file_name()? != "out" {
        return None;
    }
    // Cargo v1 uses <profile>/build/<package>-<hash>/out, while v2 uses
    // <profile>/build/<package>/<hash>/out. Find the build directory instead
    // of assuming that the profile is always at the same ancestor depth.
    let build = out
        .ancestors()
        .find(|dir| dir.file_name().is_some_and(|name| name == "build"))?;
    // Do not mistake an unrelated build directory higher in an unfamiliar
    // path for Cargo's build directory. from_env falls back to PROFILE.
    let suffix_depth = out.strip_prefix(build).ok()?.components().count();
    if !matches!(suffix_depth, 2 | 3) {
        return None;
    }
    build.parent()?.file_name()?.to_str()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn config() -> BuildConfig {
        BuildConfig {
            mode: FlutterEngineBuild::Release,
            shell: None,
            engine: None,
            lib_dir: None,
            data_dir: None,
            default_config_dir: None,
        }
    }

    #[test]
    fn cargo_output_keeps_custom_profile_name() {
        assert_eq!(
            output_profile(Path::new("/build/target/profile/build/veshell-hash/out")),
            Some("profile")
        );
        assert_eq!(
            output_profile(Path::new(
                "/build/target/aarch64-unknown-linux-gnu/debug/build/veshell-hash/out"
            )),
            Some("debug")
        );
        assert_eq!(
            "profile".parse::<FlutterEngineBuild>().unwrap(),
            FlutterEngineBuild::Profile
        );
        assert!("distro-release".parse::<FlutterEngineBuild>().is_err());
    }

    #[test]
    fn cargo_output_supports_both_build_dir_layouts() {
        for profile in ["debug", "release", "profile", "distro-release"] {
            for root in ["/build/target", "/cache/aarch64-unknown-linux-gnu"] {
                for suffix in ["build/veshell-hash/out", "build/veshell/hash/out"] {
                    let out = PathBuf::from(root).join(profile).join(suffix);
                    assert_eq!(output_profile(&out), Some(profile), "{}", out.display());
                }
            }
        }
    }

    #[test]
    fn cargo_output_does_not_guess_from_an_unrecognized_layout() {
        for out in [
            "/cache/release/veshell/hash/out",
            "/cache/build/unrecognized/release/veshell/hash/out",
            "/cache/release/build/veshell/hash/run",
            "/cache/release/build/veshell-hash",
            "/out",
            "out",
        ] {
            assert_eq!(output_profile(Path::new(out)), None, "{out}");
        }
    }

    #[test]
    fn external_inputs_must_be_paired() {
        let mut cfg = config();
        cfg.shell = Some("/bundle".into());
        assert!(cfg
            .validate()
            .unwrap_err()
            .contains("both VESHELL_PREBUILT_SHELL"));
        cfg.shell = None;
        cfg.engine = Some("/engine".into());
        assert!(cfg.validate().is_err());
    }

    #[test]
    fn installed_paths_must_be_paired_and_absolute() {
        let mut cfg = config();
        cfg.lib_dir = Some("/usr/lib/veshell".into());
        assert!(cfg.validate().is_err());
        cfg.data_dir = Some("/usr/share/veshell/data".into());
        assert!(cfg.validate().is_ok());
        cfg.data_dir = Some("stage/usr/share/veshell/data".into());
        assert!(cfg.validate().is_err());
    }

    #[test]
    fn external_bundle_matches_requested_mode() {
        let root = env::temp_dir().join(format!("veshell-build-config-{}", std::process::id()));
        let shell = root.join("shell");
        let engine = root.join("engine");
        std::fs::create_dir_all(shell.join("data/flutter_assets")).unwrap();
        std::fs::create_dir_all(shell.join("lib")).unwrap();
        for mode in ["debug", "profile", "release"] {
            std::fs::create_dir_all(engine.join(mode)).unwrap();
            std::fs::write(engine.join(mode).join("libflutter_engine.so"), "engine").unwrap();
        }
        std::fs::write(engine.join("flutter_embedder.h"), "header").unwrap();
        std::fs::write(shell.join("data/icudtl.dat"), "icu").unwrap();
        let mut cfg = config();
        cfg.shell = Some(shell.clone());
        cfg.engine = Some(engine);
        assert!(cfg.validate().is_err());
        std::fs::write(shell.join("lib/libapp.so"), "aot").unwrap();
        assert!(cfg.validate().is_ok());
        cfg.mode = FlutterEngineBuild::Profile;
        assert!(cfg.validate().is_ok());
        cfg.mode = FlutterEngineBuild::Debug;
        assert!(cfg.validate().is_err());
        std::fs::write(shell.join("data/flutter_assets/kernel_blob.bin"), "kernel").unwrap();
        assert!(cfg.validate().is_ok());
        std::fs::remove_dir_all(root).unwrap();
    }
}
