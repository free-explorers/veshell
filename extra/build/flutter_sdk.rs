use cargo_metadata::MetadataCommand;
use std::env;

const FLUTTER_REPO_URL: &str = "https://github.com/flutter/flutter.git";
pub const FLUTTER_REPO_DIR: &str = ".flutter_sdk";

pub fn install_flutter_sdk() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=extra/build/flutter_sdk.rs");
    println!("cargo:rerun-if-changed=.flutter_sdk/version");

    // Clone the flutter repo if it doesn't exist
    if !std::path::Path::new(FLUTTER_REPO_DIR).exists() {
        println!("Sdk not found, cloning flutter repo...");
        std::process::Command::new("git")
            .args(&["clone", FLUTTER_REPO_URL, FLUTTER_REPO_DIR])
            .status()?;
    }

    let _metadata = MetadataCommand::new()
        .manifest_path(env::var("CARGO_MANIFEST_PATH").unwrap())
        .exec()
        .unwrap();

    let flutter_version = _metadata.root_package().unwrap().metadata["flutter_version"]
        .as_str()
        .unwrap();

    // Check if version is different
    let current_version = match std::fs::read_to_string(".flutter_sdk/version") {
        Ok(version) => version,
        Err(_) => {
            println!("Version file not found, assuming fresh install.");
            "".to_string()
        }
    };
    if current_version == flutter_version {
        return Ok(());
    }
    println!(
        "Sdk does not match, changing flutter sdk version to {}...",
        flutter_version
    );

    // Checkout the correct version
    std::process::Command::new("git")
        .args(&["-C", FLUTTER_REPO_DIR, "checkout", flutter_version])
        .status()?;

    Ok(())
}
