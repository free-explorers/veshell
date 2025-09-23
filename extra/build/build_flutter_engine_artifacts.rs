use std::env;
use std::path::Path;
use std::process::Command;

use crate::flutter_sdk::{DEPOT_TOOLS_DIR, FLUTTER_REPO_DIR};

pub fn build_flutter_engine_artifacts() -> Result<(), Box<dyn std::error::Error>> {
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

    // Find clang root
    let clang_root = if let Ok(output) = Command::new("find")
        .arg(flutter_sdk.join("engine/src"))
        .arg("-iname")
        .arg("clang++")
        .output()
    {
        let path = String::from_utf8_lossy(&output.stdout);
        let mut path = path.trim().to_string();
        if !path.is_empty() {
            // Get parent of parent directory (clang++ -> bin -> clang_root)
            let mut components = Path::new(&path).components().collect::<Vec<_>>();
            if components.len() >= 2 {
                components.truncate(components.len() - 2);
                Path::new(&components.iter().collect::<std::path::PathBuf>()).to_path_buf()
            } else {
                Path::new(&path).to_path_buf()
            }
        } else {
            Path::new("").to_path_buf()
        }
    } else {
        Path::new("").to_path_buf()
    };

    // Build configurations
    let configs = [
        ("debug", "linux_debug_x64"),
        ("debug_unopt", "linux_debug_unopt_x64"),
        ("release", "linux_release_x64"),
        ("profile", "linux_profile_x64"),
    ];

    for (mode, out_dir) in configs {
        println!("cargo:warning=Building Flutter engine in {} mode", mode);

        // GN args
        let mut gn_args = vec![
            format!("--runtime-mode={}", mode),
            "--embedder-for-target".to_string(),
            "--no-build-embedder-examples".to_string(),
            "--no-goma".to_string(),
            "--no-rbe".to_string(),
            "--no-stripped".to_string(),
            "--no-enable-unittests".to_string(),
            "--no-dart-version-git-info".to_string(),
            "--linux-cpu=x64".to_string(),
            "--target-os=linux".to_string(),
            format!(
                "--target-sysroot={}",
                flutter_sdk
                    .join("engine/src/build/linux/debian_sid_amd64-sysroot")
                    .display()
            ),
            format!("--target-toolchain={}", clang_root.display()),
            "--target-triple=x86_64-unknown-linux-gnu".to_string(),
        ];

        if mode == "debug_unopt" {
            gn_args.push("--unoptimized".to_string());
        }

        let gn_status = Command::new("./flutter/tools/gn")
            .current_dir(flutter_sdk.join("engine/src"))
            .args(&gn_args)
            .status()?;

        if !gn_status.success() {
            return Err(format!("GN failed for {} mode", mode).into());
        }

        // Run ninja
        let ninja_status = Command::new("ninja")
            .arg("-C")
            .arg(format!("out/{}", out_dir))
            .current_dir(flutter_sdk.join("engine/src"))
            .status()?;

        if !ninja_status.success() {
            return Err(format!("Ninja build failed for {} mode", mode).into());
        }

        // Tell Cargo about the output directory
        println!(
            "cargo:rustc-link-search=native={}",
            flutter_sdk
                .join("engine/src")
                .join(format!("out/{}", out_dir))
                .display()
        );
    }
    Ok(())
}
