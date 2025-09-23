use cargo_metadata::MetadataCommand;
use std::{env, path::Path, process::Command};

pub const FLUTTER_REPO_DIR: &str = ".flutter_sdk";
pub const DEPOT_TOOLS_DIR: &str = ".depot_tools";

pub fn install_flutter_sdk() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=extra/build/flutter_sdk.rs");
    println!("cargo:rerun-if-changed=.flutter_sdk");

    // Checkout the correct version
    std::process::Command::new("git")
        .args(&["submodule", "update", "--init", "--recursive"])
        .status()?;

    // Set up environment
    let flutter_sdk = Path::new(FLUTTER_REPO_DIR);
    let depot_tools = Path::new(DEPOT_TOOLS_DIR);

    // Verify paths exist
    assert!(
        flutter_sdk.exists(),
        "Flutter SDK not found at {}. Have you run the setup script?",
        flutter_sdk.display()
    );

    assert!(
        depot_tools.exists(),
        "Depot tools not found at {}. Have you run the setup script?",
        depot_tools.display()
    );

    // Set up environment variables
    env::set_var(
        "PATH",
        format!(
            "{}:{}:{}",
            env::var("PATH").unwrap_or_default(),
            depot_tools.canonicalize()?.display(),
            flutter_sdk.join("bin").canonicalize()?.display(),
        ),
    );

    // setup gclient by copying .gclient file
    let gclient_path = Path::new(FLUTTER_REPO_DIR).join(".gclient");
    if !gclient_path.exists() {
        println!("cargo:warning=Initializing gclient environment");

        // Copy the .gclient file from the flutter repo
        std::fs::copy(
            Path::new(FLUTTER_REPO_DIR).join("engine/scripts/standard.gclient"),
            gclient_path,
        )?;
    }
    println!("cargo:warning=here2");
    print!(
        "cargo:warning=currentDir {:?}",
        std::fs::canonicalize(FLUTTER_REPO_DIR)?
    );

    let output = Command::new("gclient")
        .arg("sync")
        .current_dir(std::fs::canonicalize(FLUTTER_REPO_DIR)?)
        .output()?;
    println!("cargo:warning=here3");

    assert!(
        output.status.success(),
        "Failed to run gclient sync: {}",
        String::from_utf8_lossy(&output.stderr)
    );

    Ok(())
}
