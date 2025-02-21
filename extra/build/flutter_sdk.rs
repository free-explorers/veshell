use cargo_metadata::MetadataCommand;

const FLUTTER_REPO_URL: &str = "https://github.com/flutter/flutter.git";
pub const FLUTTER_REPO_DIR: &str = ".flutter_sdk";

pub fn install_flutter_sdk() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=extra/build/flutter_sdk.rs");

    // Clone the flutter repo if it doesn't exist
    if !std::path::Path::new(FLUTTER_REPO_DIR).exists() {
        std::process::Command::new("git")
            .args(&["clone", FLUTTER_REPO_URL, FLUTTER_REPO_DIR])
            .status()?;
    }

    let _metadata = MetadataCommand::new()
        .manifest_path(env!("CARGO_MANIFEST_PATH"))
        .exec()
        .unwrap();

    let flutter_version = _metadata.root_package().unwrap().metadata["flutter_version"]
        .as_str()
        .unwrap();

    // Checkout the correct version
    std::process::Command::new("git")
        .args(&["-C", FLUTTER_REPO_DIR, "checkout", flutter_version])
        .status()?;

    Ok(())
}
