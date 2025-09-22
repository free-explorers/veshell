use cargo_metadata::MetadataCommand;
use std::env;

const FLUTTER_REPO_URL: &str = "https://github.com/flutter/flutter.git";
pub const FLUTTER_REPO_DIR: &str = ".flutter_sdk";

pub fn install_flutter_sdk() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=extra/build/flutter_sdk.rs");
    println!("cargo:rerun-if-changed=.flutter_sdk");

    // Checkout the correct version
    std::process::Command::new("git")
        .args(&["submodule", "update", "--init", "--recursive"])
        .status()?;

    Ok(())
}
