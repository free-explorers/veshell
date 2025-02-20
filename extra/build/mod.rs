use std::fmt::{Display, Formatter};
use std::str::FromStr;
use std::{env, io};

use flutter_engine_lib::link_flutter_engine_shared_library;
use flutter_sdk::install_flutter_sdk;
use shell::build_shell;

mod flutter_engine_lib;
mod flutter_sdk;
mod shell;

fn main() {
    println!("cargo:rerun-if-changed=build/main.rs");

    // print env vars
    let flutter_engine_build = match env::var("OUT_DIR") {
        Ok(out_dir) => {
            let profile_folder = out_dir.split('/').nth_back(3).unwrap_or("debug");
            println!("cargo:rustc-env=CARGO_PROFILE={}", profile_folder);
            FlutterEngineBuild::from_str(profile_folder)
                .expect("The profile folder name must be one of debug, profile, release")
        }
        Err(_) => FlutterEngineBuild::Debug,
    };

    // Install flutter and download Engine shared libs
    match install_flutter_sdk() {
        Ok(_) => println!("Flutter SDK installed successfully"),
        Err(e) => eprintln!("Failed to install Flutter SDK: {}", e),
    }

    match build_shell(flutter_engine_build) {
        Ok(_) => println!("Shell built successfully"),
        Err(e) => eprintln!("Failed to build shell: {}", e),
    }

    match link_flutter_engine_shared_library(flutter_engine_build) {
        Ok(_) => println!("Flutter engine shared library linked successfully"),
        Err(e) => eprintln!("Failed to link Flutter engine shared library: {}", e),
    }
}

#[derive(Clone, Copy)]
enum FlutterEngineBuild {
    Debug,
    Profile,
    Release,
}

impl FromStr for FlutterEngineBuild {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "debug" => Ok(FlutterEngineBuild::Debug),
            "profile" => Ok(FlutterEngineBuild::Profile),
            "release" => Ok(FlutterEngineBuild::Release),
            _ => Err(()),
        }
    }
}

impl Display for FlutterEngineBuild {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            FlutterEngineBuild::Debug => write!(f, "debug"),
            FlutterEngineBuild::Profile => write!(f, "profile"),
            FlutterEngineBuild::Release => write!(f, "release"),
        }
    }
}
