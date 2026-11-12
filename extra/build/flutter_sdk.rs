use cargo_metadata::MetadataCommand;
use std::env;

const FLUTTER_REPO_URL: &str = "https://github.com/flutter/flutter.git";
pub const FLUTTER_REPO_DIR: &str = ".flutter_sdk";

pub fn install_flutter_sdk() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=extra/build/flutter_sdk.rs");

    // Clone the flutter repo if it doesn't exist
    if !std::path::Path::new(FLUTTER_REPO_DIR).exists() {
        println!("Sdk not found, cloning flutter repo...");
        let cloned = std::process::Command::new("git")
            .args(["clone", FLUTTER_REPO_URL, FLUTTER_REPO_DIR])
            .status()?;
        if !cloned.success() {
            return Err("Failed to clone the project Flutter SDK".into());
        }
    }

    let manifest_path = match env::var("CARGO_MANIFEST_PATH") {
        Ok(path) => path,
        Err(_) => {
            println!("CARGO_MANIFEST_PATH not set, assuming root package");
            format!("{}/Cargo.toml", env::var("CARGO_MANIFEST_DIR").unwrap())
        }
    };

    let _metadata = MetadataCommand::new()
        .manifest_path(manifest_path)
        .no_deps()
        .other_options(vec!["--offline".to_owned()])
        .exec()
        .unwrap();

    let flutter_version = _metadata.root_package().unwrap().metadata["flutter_version"]
        .as_str()
        .unwrap();

    // Check if version is different. The checkout is the source of truth: the
    // `.flutter_sdk/version` file this used to read no longer ships with
    // Flutter, and a missing `rerun-if-changed` file made cargo treat the
    // package as dirty on every build (rerunning this script, the Flutter
    // build and the Rust compile behind it).
    let current_version = checked_out_version().unwrap_or_default();
    if current_version == flutter_version {
        return Ok(());
    }
    println!(
        "Sdk does not match, changing flutter sdk version to {}...",
        flutter_version
    );

    // Checkout the correct version. The local clone may predate the pinned
    // tag, so fetch it on demand instead of silently falling back to whatever
    // revision happens to be checked out.
    let checkout = |version: &str| -> std::io::Result<std::process::ExitStatus> {
        std::process::Command::new("git")
            .args(["-C", FLUTTER_REPO_DIR, "checkout", version])
            .status()
    };

    let mut checked_out = checkout(flutter_version)?;
    if !checked_out.success() {
        println!(
            "Flutter SDK tag {} missing locally, fetching it...",
            flutter_version
        );
        let fetched = std::process::Command::new("git")
            .args([
                "-C",
                FLUTTER_REPO_DIR,
                "fetch",
                "origin",
                "tag",
                flutter_version,
            ])
            .status()?;
        if !fetched.success() {
            return Err(format!(
                "Failed to fetch Flutter SDK tag {} from {}",
                flutter_version, FLUTTER_REPO_URL
            )
            .into());
        }
        checked_out = checkout(flutter_version)?;
    }
    if !checked_out.success() {
        return Err(format!(
            "Failed to check out Flutter SDK tag {} in {}",
            flutter_version, FLUTTER_REPO_DIR
        )
        .into());
    }

    Ok(())
}

/// The tag the SDK checkout sits on, when it sits exactly on a tag.
///
/// A branch or untagged commit yields `None`, which makes the caller check out
/// the pinned tag instead of silently using whatever revision is checked out.
fn checked_out_version() -> Option<String> {
    let output = std::process::Command::new("git")
        .args([
            "-C",
            FLUTTER_REPO_DIR,
            "describe",
            "--tags",
            "--exact-match",
        ])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let version = String::from_utf8(output.stdout).ok()?;
    Some(version.trim().to_string())
}
