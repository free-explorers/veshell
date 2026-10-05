use crate::flutter_sdk::FLUTTER_REPO_DIR;
use crate::FlutterEngineBuild;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::{env, io};

use flate2::read::GzDecoder;

const FLUTTER_ENGINE_LIBS_DIR: &str = "extra/third_party/flutter_engine";
const FLUTTER_ENGINE_LIB_NAME: &str = "libflutter_engine.so";
const FLUTTER_ENGINE_HEADER_NAME: &str = "flutter_embedder.h";
const FLUTTER_ENGINE_LINK_NAME: &str = "flutter_engine";
pub fn link_flutter_engine_shared_library(
    flutter_engine_build: FlutterEngineBuild,
) -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=extra/build/flutter_engine_lib.rs");
    println!("cargo:rerun-if-changed={FLUTTER_ENGINE_LIBS_DIR}");

    println!("cargo:rerun-if-env-changed=VESHELL_ENGINE_DIR");
    println!("cargo:rerun-if-env-changed=VESHELL_LIB_DIR");
    println!("cargo:rerun-if-env-changed=SKIP_FLUTTER_ENGINE_DOWNLOAD");
    if env::var_os("VESHELL_ENGINE_DIR").is_none() {
        let flutter_engine_revision = get_flutter_engine_revision()?;
        if should_download_flutter_engine_library(&flutter_engine_revision, flutter_engine_build) {
            download_flutter_engine_library(&flutter_engine_revision, flutter_engine_build)?;
        }
    }

    // Generate the embedder bindings
    generate_embedder_bindings();

    link_libflutter_engine(flutter_engine_build);
    Ok(())
}

fn get_flutter_engine_revision() -> Result<String, Box<dyn std::error::Error>> {
    let engine_version_path = format!("{FLUTTER_REPO_DIR}/bin/internal/engine.version");
    let revision = std::fs::read_to_string(engine_version_path)?;
    if revision.trim().is_empty() {
        return Err("Flutter SDK engine revision is empty".into());
    }
    Ok(revision.trim().to_owned())
}

fn should_download_flutter_engine_library(
    flutter_engine_revision: &str,
    flutter_engine_build: FlutterEngineBuild,
) -> bool {
    if env::var_os("SKIP_FLUTTER_ENGINE_DOWNLOAD").is_some() {
        return false;
    }
    // Is the revision different? If so, Flutter was probably upgraded.
    let libs_revision_file =
        format!("{FLUTTER_ENGINE_LIBS_DIR}/.flutter_engine_revision.{flutter_engine_build}");
    match std::fs::read_to_string(libs_revision_file) {
        Ok(libs_revision) => {
            if libs_revision != flutter_engine_revision {
                return true;
            }
        }
        Err(_) => return true,
    };
    if !matches!(std::fs::read_to_string(format!("{FLUTTER_ENGINE_LIBS_DIR}/.flutter_engine_header_revision")),
        Ok(header_revision) if header_revision == flutter_engine_revision)
    {
        return true;
    }
    // Does the shared library exist?
    if Path::new(&format!(
        "{FLUTTER_ENGINE_LIBS_DIR}/{flutter_engine_build}/{FLUTTER_ENGINE_LIB_NAME}"
    ))
    .is_file()
        && Path::new(&format!(
            "{FLUTTER_ENGINE_LIBS_DIR}/{FLUTTER_ENGINE_HEADER_NAME}"
        ))
        .is_file()
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
    let arch = match env::var("CARGO_CFG_TARGET_ARCH").as_deref() {
        Ok("x86_64") => "x86_64",
        Ok("aarch64") => "arm64",
        _ => return Err("Unsupported Flutter engine target architecture".into()),
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

    for path in [
        format!("{FLUTTER_ENGINE_LIBS_DIR}/{flutter_engine_build}/{FLUTTER_ENGINE_LIB_NAME}"),
        format!("{FLUTTER_ENGINE_LIBS_DIR}/{FLUTTER_ENGINE_HEADER_NAME}"),
    ] {
        let metadata = std::fs::metadata(&path)?;
        if !metadata.is_file() || metadata.len() == 0 {
            return Err(
                format!("Engine archive is missing a nonempty required file: {path}").into(),
            );
        }
    }

    // Mark complete only after both required artifacts are installed.
    let revision_file_path =
        format!("{FLUTTER_ENGINE_LIBS_DIR}/.flutter_engine_revision.{flutter_engine_build}");
    let mut revision_file = std::fs::File::create(revision_file_path)
        .expect("Failed to create .flutter_engine_revision");
    write!(revision_file, "{}", flutter_engine_revision)
        .expect("Failed to write .flutter_engine_revision");
    std::fs::write(
        format!("{FLUTTER_ENGINE_LIBS_DIR}/.flutter_engine_header_revision"),
        flutter_engine_revision,
    )?;
    Ok(())
}

fn download_from_url(url: &str) -> Result<bytes::Bytes, reqwest::Error> {
    println!("Downloading from {}", url);
    Ok(reqwest::blocking::get(url)?.error_for_status()?.bytes()?)
}

fn generate_embedder_bindings() {
    let engine_dir =
        env::var("VESHELL_ENGINE_DIR").unwrap_or_else(|_| FLUTTER_ENGINE_LIBS_DIR.to_owned());
    let embedder_header_path = format!("{engine_dir}/{FLUTTER_ENGINE_HEADER_NAME}");
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

    let engine_dir =
        env::var("VESHELL_ENGINE_DIR").unwrap_or_else(|_| FLUTTER_ENGINE_LIBS_DIR.to_owned());
    let libflutter_engine_dir = format!("{engine_dir}/{flutter_engine_build}");
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
