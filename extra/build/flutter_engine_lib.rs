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
    println!("cargo:rerun-if-env-changed=VESHELL_ENGINE_REPO");
    println!("cargo:rerun-if-env-changed=SKIP_FLUTTER_ENGINE_DOWNLOAD");
    println!("cargo:rerun-if-env-changed=VESHELL_LOCAL_ENGINE");

    let (header_path, lib_dir) = if let Some(out_dir) = local_engine(flutter_engine_build)? {
        (
            out_dir.join(FLUTTER_ENGINE_HEADER_NAME),
            out_dir.display().to_string(),
        )
    } else {
        let engine_dir =
            env::var("VESHELL_ENGINE_DIR").unwrap_or_else(|_| FLUTTER_ENGINE_LIBS_DIR.to_owned());
        if env::var_os("VESHELL_ENGINE_DIR").is_none() {
            // The engine is upstream's at the SDK's revision with Veshell's
            // patches: both name the artifact.
            let flutter_engine_revision = format!(
                "{}-{}",
                get_flutter_engine_revision()?,
                get_flutter_engine_patchset()?
            );
            if should_download_flutter_engine_library(
                &flutter_engine_revision,
                flutter_engine_build,
            ) {
                download_flutter_engine_library(&flutter_engine_revision, flutter_engine_build)?;
            }
        }
        (
            PathBuf::from(format!("{engine_dir}/{FLUTTER_ENGINE_HEADER_NAME}")),
            format!("{engine_dir}/{flutter_engine_build}"),
        )
    };

    generate_embedder_bindings(&header_path);
    link_libflutter_engine(&lib_dir);
    Ok(())
}

/// The output directory of a locally built engine, when one is selected.
///
/// `VESHELL_LOCAL_ENGINE` names a gn output directory produced by
/// `extra/engine/engine.sh build`, such as `.../engine/src/out/host_debug_unopt`.
/// The engine is built from the pinned SDK's revision, so the shell the SDK
/// builds still matches it: unlike `VESHELL_ENGINE_DIR`, it needs no prebuilt
/// shell. It is linked in place and never downloaded over.
fn local_engine(
    flutter_engine_build: FlutterEngineBuild,
) -> Result<Option<PathBuf>, Box<dyn std::error::Error>> {
    let Some(out_dir) = env::var_os("VESHELL_LOCAL_ENGINE") else {
        return Ok(None);
    };
    if env::var_os("VESHELL_ENGINE_DIR").is_some() {
        return Err("Set VESHELL_LOCAL_ENGINE or VESHELL_ENGINE_DIR, not both.".into());
    }
    let out_dir = PathBuf::from(out_dir).canonicalize().map_err(|error| {
        format!("VESHELL_LOCAL_ENGINE does not name an engine build directory: {error}")
    })?;
    // A debug shell's kernel cannot run on a profile or release engine, nor an
    // AOT shell on a debug one: the gn variant must match the Flutter mode.
    let name = out_dir
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or_default();
    let expected = format!("host_{flutter_engine_build}");
    if name != expected && !name.starts_with(&format!("{expected}_")) {
        return Err(format!(
            "VESHELL_LOCAL_ENGINE is {name}, but this is a {flutter_engine_build} build: \
             use an engine built as {expected} (extra/engine/engine.sh build)"
        )
        .into());
    }
    for file in [FLUTTER_ENGINE_LIB_NAME, FLUTTER_ENGINE_HEADER_NAME] {
        if !out_dir.join(file).is_file() {
            return Err(format!(
                "{} is missing: build the engine first (extra/engine/engine.sh build)",
                out_dir.join(file).display()
            )
            .into());
        }
    }
    println!(
        "cargo:warning=Linking the local engine in {}",
        out_dir.display()
    );
    Ok(Some(out_dir))
}

/// The engine patches the application is pinned to (`Cargo.toml`
/// `flutter_engine_patchset`).
fn get_flutter_engine_patchset() -> Result<String, Box<dyn std::error::Error>> {
    let manifest_path = env::var("CARGO_MANIFEST_PATH").unwrap_or_else(|_| {
        format!("{}/Cargo.toml", env::var("CARGO_MANIFEST_DIR").unwrap())
    });
    let metadata = cargo_metadata::MetadataCommand::new()
        .manifest_path(manifest_path)
        .no_deps()
        .other_options(vec!["--offline".to_owned()])
        .exec()?;
    let patchset = metadata
        .root_package()
        .and_then(|package| package.metadata["flutter_engine_patchset"].as_str())
        .ok_or("Cargo.toml has no package.metadata.flutter_engine_patchset")?;
    if patchset.is_empty() {
        return Err("Cargo.toml's flutter_engine_patchset is empty".into());
    }
    Ok(patchset.to_owned())
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
    true
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

    // Download the archive from our own source-built engine releases, which carry
    // every mode for each revision the application is pinned to. Set
    // VESHELL_ENGINE_REPO to point elsewhere, such as meta-flutter; that mirror
    // lags behind new Flutter revisions, so it cannot be the default. Builds that
    // supply VESHELL_ENGINE_DIR never reach this.
    let engine_repo = env::var("VESHELL_ENGINE_REPO")
        .unwrap_or_else(|_| "free-explorers/flutter-engine".to_owned());
    let asset = format!("linux-engine-sdk-{flutter_engine_build}-{arch}-{flutter_engine_revision}");
    let url = format!("https://github.com/{engine_repo}/releases/download/{asset}/{asset}.tar.gz");
    let sha256_url = format!("{}.sha256", url);

    // Download the archive and its SHA256 checksum
    let bytes = download_from_url(&url).unwrap_or_else(|error| {
        panic!(
            "Failed to download the Flutter engine for {flutter_engine_revision} from {engine_repo}: {error}\n\
             Set VESHELL_ENGINE_REPO to choose another release source, or VESHELL_ENGINE_DIR to use \
             an engine that is already extracted."
        )
    });
    let sha256_bytes = download_from_url(&sha256_url).unwrap_or_else(|error| {
        panic!("Failed to download the Flutter engine SHA256 checksum from {engine_repo}: {error}")
    });

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
    reqwest::blocking::get(url)?.error_for_status()?.bytes()
}

fn generate_embedder_bindings(embedder_header_path: &Path) {
    let embedder_header_path = embedder_header_path.display().to_string();
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

fn link_libflutter_engine(libflutter_engine_dir: &str) {
    link_libgl();

    println!("cargo:rerun-if-changed={libflutter_engine_dir}/{FLUTTER_ENGINE_LIB_NAME}");
    println!("cargo:rustc-link-search={libflutter_engine_dir}");
    println!("cargo:rustc-link-lib={FLUTTER_ENGINE_LINK_NAME}");

    if let Ok(lib_dir) = std::env::var("VESHELL_LIB_DIR") {
        println!("cargo:rustc-link-arg=-Wl,-rpath={}", lib_dir);
    } else {
        // link when is running from source
        println!("cargo:rustc-link-arg=-Wl,-rpath={}", libflutter_engine_dir);
    }
}

fn link_libgl() {
    // libflutter_engine.so uses libGL.so, not the Rust code.
    // rustc has no idea and thinks libGL.so is not needed.
    // --no-as-needed is needed to force the linker to link libGL.so.
    // We manually put -lGL here because `println!("cargo:rustc-link-lib=GL")` doesn't work.
    println!("cargo:rustc-link-arg=-Wl,--no-as-needed,-lGL");
}
