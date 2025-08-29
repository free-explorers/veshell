use crate::flutter_sdk::FLUTTER_REPO_DIR;
use crate::FlutterEngineBuild;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::{env, io};

use flate2::read::GzDecoder;
use lazy_static::lazy_static;

const FLUTTER_ENGINE_LIBS_DIR: &str = "extra/third_party/flutter_engine";
const FLUTTER_ENGINE_LIB_NAME: &str = "libflutter_engine.so";
const FLUTTER_ENGINE_HEADER_NAME: &str = "flutter_embedder.h";
const FLUTTER_ENGINE_LINK_NAME: &str = "flutter_engine";
lazy_static! {
    static ref LIBS_REVISION_FILE: String =
        format!("{FLUTTER_ENGINE_LIBS_DIR}/.flutter_engine_revision");
}

pub fn link_flutter_engine_shared_library(
    flutter_engine_build: FlutterEngineBuild,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=extra/build/flutter_engine_lib.rs");
    println!("cargo:rerun-if-changed={FLUTTER_ENGINE_LIBS_DIR}");

    // Get the desired flutter engine revision
    let flutter_engine_revision = get_flutter_engine_revision();

    // Check if we need to download the flutter engine library
    let should_download =
        should_download_flutter_engine_library(&flutter_engine_revision, flutter_engine_build);

    if should_download {
        download_flutter_engine_library(&flutter_engine_revision, flutter_engine_build).unwrap();
    }

    // Generate the embedder bindings
    generate_embedder_bindings();

    link_libflutter_engine(flutter_engine_build);
    Ok(())
}

fn get_flutter_engine_revision() -> String {
    let mut git_cmd = Command::new("git");
    let mut engine_path = String::from(FLUTTER_REPO_DIR);
    engine_path.push_str("/engine");
    git_cmd.current_dir(engine_path);
    git_cmd.args(&["log", "-1", "--format=%H", "--", "."]);

    let output = git_cmd.output();

    match output {
        Ok(output) => {
            if output.status.success() {
                let commit_hash = String::from_utf8(output.stdout).expect("Not UTF-8");
                return commit_hash.trim().to_string();
            } else {
                println!("Error: Failed to get git commit hash");
                return String::new();
            }
        }
        Err(e) => {
            println!("Error: {:?}, failed to execute git command", e);
            return String::new();
        }
    }
}

fn should_download_flutter_engine_library(
    flutter_engine_revision: &str,
    flutter_engine_build: FlutterEngineBuild,
) -> bool {
    if option_env!("SKIP_FLUTTER_ENGINE_DOWNLOAD").is_some() {
        return false;
    }
    // Is the revision different? If so, Flutter was probably upgraded.
    match std::fs::read_to_string(&*LIBS_REVISION_FILE) {
        Ok(libs_revision) => {
            if libs_revision != flutter_engine_revision {
                return true;
            }
        }
        Err(_) => return true,
    };
    // Does the shared library exist?
    if Path::new(&format!(
        "{FLUTTER_ENGINE_LIBS_DIR}/{flutter_engine_build}/{FLUTTER_ENGINE_LIB_NAME}"
    ))
    .exists()
    {
        return false;
    }
    return true;
}

fn download_flutter_engine_library(
    flutter_engine_revision: &str,
    flutter_engine_build: FlutterEngineBuild,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("Downloading flutter engine library...");
    let arch = if cfg!(target_arch = "x86_64") {
        "x86_64"
    } else if cfg!(target_arch = "aarch64") {
        "arm64"
    } else {
        panic!("Unsupported architecture");
    };

    // Download the archive.
    let url = format!("https://github.com/meta-flutter/flutter-engine/releases/download/linux-engine-sdk-{}-{}-{}/linux-engine-sdk-{}-{}-{}.tar.gz",
                          flutter_engine_build, arch, flutter_engine_revision,
                          flutter_engine_build, arch, flutter_engine_revision);
    let sha256_url = format!("{}.sha256", url);

    // Download the archive and its SHA256 checksum
    let bytes = download_from_url(&url)
        .expect("Failed to download Flutter engine archive. Try downgrading Flutter.");
    let sha256_bytes = download_from_url(&sha256_url)
        .expect("Failed to download Flutter engine SHA256 checksum. Try downgrading Flutter.");

    // Verify the SHA256 checksum
    let sha256_sum =
        String::from_utf8(sha256_bytes.to_vec()).expect("SHA256 checksum is not valid UTF-8");
    let expected_sha256 = sha256_sum.split(' ').next().unwrap().trim();
    let actual_sha256 = sha256::digest(bytes.to_vec()).to_string();

    if actual_sha256 != expected_sha256 {
        panic!(
            "SHA256 checksum mismatch. Expected: {}, Got: {}",
            expected_sha256, actual_sha256
        );
    }

    let tar = GzDecoder::new(io::Cursor::new(bytes));
    let mut archive = tar::Archive::new(tar);

    for entry in archive.entries()? {
        let mut entry = entry?;
        let path = entry.path()?;
        let file_name = path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("");

        let lib_dir = format!("{FLUTTER_ENGINE_LIBS_DIR}/{flutter_engine_build}");
        std::fs::create_dir_all(&lib_dir).expect("Failed to create directories");

        match file_name {
            FLUTTER_ENGINE_LIB_NAME => {
                let mut file =
                    std::fs::File::create(format!("{lib_dir}/{FLUTTER_ENGINE_LIB_NAME}"))
                        .expect("Failed to create new file");
                io::copy(&mut entry, &mut file).expect("Failed to copy Flutter engine library");
            }
            FLUTTER_ENGINE_HEADER_NAME => {
                let mut file = std::fs::File::create(format!(
                    "{FLUTTER_ENGINE_LIBS_DIR}/{FLUTTER_ENGINE_HEADER_NAME}"
                ))
                .expect("Failed to create new file");
                io::copy(&mut entry, &mut file).expect("Failed to copy Flutter engine library");
            }
            _ => {}
        }
    }

    // Remember the revision.
    let mut revision_file = std::fs::File::create(&*LIBS_REVISION_FILE)
        .expect("Failed to create .flutter_engine_revision");
    write!(revision_file, "{}", flutter_engine_revision)
        .expect("Failed to write .flutter_engine_revision");
    Ok(())
}

fn download_from_url(url: &str) -> Result<bytes::Bytes, reqwest::Error> {
    println!("Downloading from {}", url);
    Ok(reqwest::blocking::get(url)?.error_for_status()?.bytes()?)
}

fn generate_embedder_bindings() {
    let embedder_header_path = format!("{FLUTTER_ENGINE_LIBS_DIR}/{FLUTTER_ENGINE_HEADER_NAME}");
    println!("cargo:rerun-if-changed={embedder_header_path}");
    println!("Generating embedder bindings...");

    let bindings = bindgen::Builder::default()
        .header(embedder_header_path)
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .generate()
        .expect("Unable to generate bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("embedder.rs"))
        .expect("Couldn't write bindings!");
}

fn link_libflutter_engine(flutter_engine_build: FlutterEngineBuild) {
    link_libgl();

    let libflutter_engine_dir = format!("{FLUTTER_ENGINE_LIBS_DIR}/{flutter_engine_build}");
    println!("cargo:rerun-if-changed={libflutter_engine_dir}/{FLUTTER_ENGINE_LIB_NAME}");
    println!("cargo:rustc-link-search={libflutter_engine_dir}");
    println!("cargo:rustc-link-lib={FLUTTER_ENGINE_LINK_NAME}");

    if let Ok(lib_dir) = std::env::var("VESHELL_LIB_DIR") {
        println!("cargo:rustc-link-arg=-Wl,-rpath={}", lib_dir);
    } else {
        // link when is running from source
        println!("cargo:rustc-link-arg=-Wl,-rpath={}", &libflutter_engine_dir);
    }
}

fn link_libgl() {
    // libflutter_engine.so uses libGL.so, not the Rust code.
    // rustc has no idea and thinks libGL.so is not needed.
    // --no-as-needed is needed to force the linker to link libGL.so.
    // We manually put -lGL here because `println!("cargo:rustc-link-lib=GL")` doesn't work.
    println!("cargo:rustc-link-arg=-Wl,--no-as-needed,-lGL");
}
