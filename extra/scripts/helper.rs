use std::env;
use std::path::Path;
use std::process::Command;

fn main() {
    let arch = if cfg!(target_arch = "x86_64") {
        "x64"
    } else {
        "arm64"
    };

    let profile = env::var("CARGO_PROFILE").unwrap();

    bundle(arch, &profile).expect("Failed to bundle build");

    // if args --install
    if env::args().any(|arg| arg == "--install") {
        match install(arch, &profile) {
            Ok(_) => println!("Installed successfully"),
            Err(e) => println!("Failed to install: {}", e),
        }
    }
}

pub fn bundle(arch: &str, profile: &str) -> Result<(), Box<dyn std::error::Error>> {
    println!("Packaging build...\n");

    // Create the target directory
    let target_directory = format!("build/bundle/{}", profile);
    std::fs::create_dir_all(format!("{}/lib/", target_directory))
        .expect("Failed to create directory");

    // if binary doesn't exist prompt the user to build first
    if !std::path::Path::new(&format!("build/target/{}/veshell", profile)).exists() {
        panic!(
            "Binary not found, please build first: > cargo build --profile={}",
            profile
        );
    }

    // Copy binary
    std::fs::copy(
        format!("build/target/{}/{}", profile, "veshell"),
        format!("{}/{}", target_directory, "veshell"),
    )
    .expect("Failed to copy binary");

    // Copy libflutter_engine.so
    std::fs::copy(
        format!(
            "extra/third_party/flutter_engine/{}/libflutter_engine.so",
            profile
        ),
        format!("{}/lib/libflutter_engine.so", target_directory),
    )
    .expect("Failed to copy libflutter_engine.so");

    // If it's not debug, copy libapp.so
    if profile != "debug" {
        std::fs::copy(
            format!(
                "src/shell/build/linux/{}/{}/bundle/lib/libapp.so",
                arch, profile
            ),
            format!("{}/lib/libapp.so", target_directory),
        )
        .expect("Failed to copy libapp.so");
    }

    // Copy flutter bundle data
    std::process::Command::new("cp")
        .arg("-r")
        .arg(format!(
            "src/shell/build/linux/{}/{}/bundle/data",
            arch, profile
        ))
        .arg(&target_directory)
        .output()
        .expect("Failed to execute cp command");

    std::process::Command::new("cp")
        .arg("-r")
        .arg("extra/settings/")
        .arg(&target_directory)
        .output()
        .expect("Failed to execute cp command");

    Ok(())
}

fn install(_arch: &str, profile: &str) -> Result<(), Box<dyn std::error::Error>> {
    let assets_directory = "extra/assets";
    // Get the current working directory
    let current_dir = env::current_dir().expect("Failed to get current directory");
    let build_directory = current_dir.join(format!("build/bundle/{}", profile));

    println!("Installing the session in the system requires sudo privileges");

    println!(
        "Linking {}/veshell to /usr/local/bin/",
        build_directory.display()
    );
    Command::new("sudo")
        .arg("ln")
        .arg("-sf")
        .arg(format!("{}/veshell", build_directory.display()))
        .arg("/usr/local/bin/veshell")
        .output()
        .expect("Failed to create symbolic link");

    println!("Copying veshell-session to /usr/local/bin/");
    Command::new("sudo")
        .arg("cp")
        .arg(format!("{}/veshell-session", assets_directory))
        .arg("/usr/local/bin/")
        .output()
        .expect("Failed to copy veshell-session");

    if !Path::new("/usr/local/share/wayland-sessions").exists() {
        println!("Creating /usr/local/share/wayland-sessions directory");
        Command::new("sudo")
            .arg("mkdir")
            .arg("-p")
            .arg("/usr/local/share/wayland-sessions")
            .output()
            .expect("Failed to create wayland-sessions directory");
    }

    println!("Copying veshell.desktop to /usr/local/share/wayland-sessions/");
    Command::new("sudo")
        .arg("cp")
        .arg(format!("{}/veshell.desktop", assets_directory))
        .arg("/usr/local/share/wayland-sessions/")
        .output()
        .expect("Failed to copy veshell.desktop");

    println!("Changing permissions of veshell.desktop");
    Command::new("sudo")
        .arg("chmod")
        .arg("a+r")
        .arg("/usr/local/share/wayland-sessions/veshell.desktop")
        .output()
        .expect("Failed to change permissions of veshell.desktop");

    println!("Copying veshell.service to /etc/systemd/user/");
    Command::new("sudo")
        .arg("cp")
        .arg(format!("{}/veshell.service", assets_directory))
        .arg("/etc/systemd/user/")
        .output()
        .expect("Failed to copy veshell.service");

    println!("Copying veshell-shutdown.target to /etc/systemd/user/");
    Command::new("sudo")
        .arg("cp")
        .arg(format!("{}/veshell-shutdown.target", assets_directory))
        .arg("/etc/systemd/user/")
        .output()
        .expect("Failed to copy veshell-shutdown.target");

    Ok(())
}
