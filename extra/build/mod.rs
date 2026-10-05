use config::{BuildConfig, FlutterEngineBuild};
use std::env;

use flutter_engine_lib::link_flutter_engine_shared_library;
use flutter_sdk::install_flutter_sdk;
use shell::build_shell;

mod config;
mod flutter_engine_lib;
mod flutter_sdk;
mod shell;

fn main() {
    println!("cargo:rerun-if-changed=Cargo.toml");
    println!("cargo:rerun-if-changed=extra/build/mod.rs");

    println!("cargo:rerun-if-changed=extra/build/config.rs");
    for name in [
        "VESHELL_FLUTTER_MODE",
        "VESHELL_PREBUILT_SHELL",
        "VESHELL_ENGINE_DIR",
        "VESHELL_LIB_DIR",
        "VESHELL_DATA_DIR",
        "VESHELL_DEFAULT_CONFIG_DIR",
    ] {
        println!("cargo:rerun-if-env-changed={name}");
    }
    let config =
        BuildConfig::from_env().unwrap_or_else(|e| panic!("Invalid build configuration: {e}"));
    let flutter_engine_build = config.mode;
    println!("cargo:rustc-env=CARGO_PROFILE={flutter_engine_build}");
    if let Some(engine) = &config.engine {
        env::set_var("VESHELL_ENGINE_DIR", engine);
    }
    if let Some(bundle) = &config.shell {
        println!("cargo:rerun-if-changed={}", bundle.display());
    } else {
        if let (Ok(host), Ok(target)) = (env::var("HOST"), env::var("TARGET")) {
            assert_eq!(host, target, "Automatic SDK/engine builds are native-only; cross builds require matching external shell and engine inputs.");
        }
        match install_flutter_sdk() {
            Ok(_) => println!("Flutter SDK installed successfully"),
            Err(e) => panic!("Failed to install Flutter SDK: {}", e),
        }

        match build_shell(flutter_engine_build) {
            Ok(_) => println!("Shell built successfully"),
            Err(e) => panic!("Failed to build shell: {}", e),
        }
    }

    if config.lib_dir.is_none() {
        let bundle = config.shell.unwrap_or_else(|| {
            let arch = match env::var("CARGO_CFG_TARGET_ARCH").as_deref() {
                Ok("x86_64") => "x64",
                Ok("aarch64") => "arm64",
                _ => panic!("Unsupported automatic Flutter target architecture"),
            };
            std::path::PathBuf::from(format!(
                "src/shell/build/linux/{arch}/{flutter_engine_build}/bundle"
            ))
            .canonicalize()
            .expect("Flutter shell bundle is missing")
        });
        println!(
            "cargo:rustc-env=VESHELL_LIB_DIR={}",
            bundle.join("lib").display()
        );
        println!(
            "cargo:rustc-env=VESHELL_DATA_DIR={}",
            bundle.join("data").display()
        );
        if config.default_config_dir.is_none() {
            let defaults = std::path::Path::new("extra/settings/default")
                .canonicalize()
                .expect("Default settings are missing");
            println!(
                "cargo:rustc-env=VESHELL_DEFAULT_CONFIG_DIR={}",
                defaults.display()
            );
        }
    }

    match link_flutter_engine_shared_library(flutter_engine_build) {
        Ok(_) => println!("Flutter engine shared library linked successfully"),
        Err(e) => panic!("Failed to link Flutter engine shared library: {}", e),
    }
}
