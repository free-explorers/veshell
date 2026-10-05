use std::{env, path::Path};

use crate::{flutter_sdk::FLUTTER_REPO_DIR, FlutterEngineBuild};
use lazy_static::lazy_static;

lazy_static! {
    static ref dart_bin_path: String = format!("{FLUTTER_REPO_DIR}/bin/dart");
    static ref flutter_bin_path: String = format!("{FLUTTER_REPO_DIR}/bin/flutter");
}

const SHELL_DIRECTORY: &str = "src/shell";

pub fn build_shell(
    flutter_engine_build: FlutterEngineBuild,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=extra/build/shell.rs");
    println!("cargo:rerun-if-changed=src/shell/pubspec.yaml");
    println!("cargo:rerun-if-changed=src/shell/pubspec.lock");
    println!("cargo:rerun-if-changed=src/shell/assets");
    println!("cargo:rerun-if-changed=src/shell/lib");
    println!("cargo:rerun-if-env-changed=VESHELL_POLKIT_HELPER_PATH");

    let absolute_flutter_bin = Path::new(&*flutter_bin_path).canonicalize()?;
    let absolute_dart_bin = Path::new(&*dart_bin_path).canonicalize()?;
    let absolute_shell_directory = Path::new(&SHELL_DIRECTORY).canonicalize()?;
    // get pub dependencies
    let output = std::process::Command::new(absolute_flutter_bin.clone())
        .arg("pub")
        .arg("get")
        .current_dir(absolute_shell_directory.clone())
        .status()?;

    if !output.success() {
        panic!("Failed to get shell pub dependencies");
    }

    // run build_runner
    println!("Running build_runner...");
    let output = std::process::Command::new(absolute_dart_bin)
        .arg("run")
        .arg("build_runner")
        .arg("build")
        .current_dir(absolute_shell_directory.clone())
        .status()?;
    if !output.success() {
        panic!("Failed to run build_runner");
    }

    // build shell
    println!("Building shell...");
    let mut command = std::process::Command::new(absolute_flutter_bin);
    command
        .arg("build")
        .arg("linux")
        .arg(match flutter_engine_build {
            FlutterEngineBuild::Debug => "--debug",
            FlutterEngineBuild::Profile => "--profile",
            FlutterEngineBuild::Release => "--release",
        });
    if let Ok(helper) = env::var("VESHELL_POLKIT_HELPER_PATH") {
        if !Path::new(&helper).is_absolute() {
            return Err(
                "VESHELL_POLKIT_HELPER_PATH must be an absolute final installation path".into(),
            );
        }
        command.arg(format!("--dart-define=VESHELL_POLKIT_HELPER_PATH={helper}"));
    }
    let output = command
        .current_dir(absolute_shell_directory.clone())
        .status()?;

    if !output.success() {
        // print the command executed
        println!("Command executed: {:?}", output);
        panic!("Failed to build shell");
    }
    Ok(())
}
