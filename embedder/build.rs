use std::{env, io};
use std::fmt::{Display, Formatter};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::str::FromStr;

use lazy_static::lazy_static;

const FLUTTER_ENGINE_LIBS_DIR: &str = "third_party/flutter_engine";
const FLUTTER_ENGINE_LIB_NAME: &str = "libflutter_engine.so";
const FLUTTER_ENGINE_LINK_NAME: &str = "flutter_engine";
lazy_static! {
    static ref LIBS_REVISION_FILE: String =
        format!("{FLUTTER_ENGINE_LIBS_DIR}/.flutter_engine_revision");
}

fn main() {
    match std::env::var("FLUTTER_ENGINE_BUILD") {
        Ok(val) => println!("FLUTTER_ENGINE_BUILD: {}", val),
        Err(_e) => println!("Couldn't read FLUTTER_ENGINE_BUILD"),
    }
    let flutter_engine_revision = get_flutter_engine_revision();
    println!("cargo:rerun-if-changed={FLUTTER_ENGINE_LIBS_DIR}");

    let flutter_engine_build = match option_env!("FLUTTER_ENGINE_BUILD") {
        Some(build) => FlutterEngineBuild::from_str(&build)
            .expect("FLUTTER_ENGINE_BUILD must be one of debug, profile, release"),
        None => FlutterEngineBuild::Debug,
    };

    if should_download_flutter_engine_library(&flutter_engine_revision, flutter_engine_build) {
        download_flutter_engine_library(&flutter_engine_revision, flutter_engine_build);
    }
    generate_embedder_bindings();
    link_libflutter_engine(flutter_engine_build);
}

fn get_flutter_engine_revision() -> String {
    let flutter_cli_path = exec("which", &["flutter"]);
    let flutter_cli_path = Path::new(&flutter_cli_path).parent().unwrap();
    let engine_revision_file = flutter_cli_path.join("internal").join("engine.version");
    let engine_revision_str = engine_revision_file.as_path().display().to_string();
    println!("cargo:rerun-if-changed={engine_revision_str}");
    std::fs::read_to_string(engine_revision_file).unwrap()
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
) {
    let arch = if cfg!(target_arch = "x86_64") {
        "x64"
    } else if cfg!(target_arch = "aarch64") {
        "arm64"
    } else {
        panic!("Unsupported architecture");
    };

    // Download the archive.
    let short_hash = flutter_engine_revision[..10].to_string();
    let url = format!("https://github.com/sony/flutter-embedded-linux/releases/download/{short_hash}/elinux-{arch}-{flutter_engine_build}.zip");
    let bytes = download_from_url(&url)
        .expect("Failed to download Flutter engine archive. Try downgrading Flutter.");
    let mut archive = zip::ZipArchive::new(io::Cursor::new(bytes)).expect("Not an archive");
    let mut lib = archive
        .by_name(FLUTTER_ENGINE_LIB_NAME)
        .expect(&format!("{FLUTTER_ENGINE_LIB_NAME} not found in archive"));

    // Extract the shared library.
    let lib_dir = format!("{FLUTTER_ENGINE_LIBS_DIR}/{flutter_engine_build}");
    std::fs::create_dir_all(&lib_dir).expect("Failed to create directories");
    let mut file = std::fs::File::create(format!("{lib_dir}/{FLUTTER_ENGINE_LIB_NAME}"))
        .expect("Failed to create new file");
    io::copy(&mut lib, &mut file).expect("Failed to copy Flutter engine library");

    // Remember the revision.
    let mut revision_file = std::fs::File::create(&*LIBS_REVISION_FILE)
        .expect("Failed to create .flutter_engine_revision");
    write!(revision_file, "{}", flutter_engine_revision)
        .expect("Failed to write .flutter_engine_revision");
}

fn exec(cmd: &str, args: &[&str]) -> String {
    let output = Command::new(cmd)
        .args(args)
        .output()
        .expect("failed to execute cmd");

    String::from_utf8(output.stdout).unwrap().trim().to_string()
}

fn download_from_url(url: &str) -> Result<bytes::Bytes, reqwest::Error> {
    Ok(reqwest::blocking::get(url)?.error_for_status()?.bytes()?)
}

fn generate_embedder_bindings() {
    let embedder_header_path = format!("{FLUTTER_ENGINE_LIBS_DIR}/embedder.h");
    println!("cargo:rerun-if-changed={embedder_header_path}");

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

    let rpath = "$ORIGIN/lib";
    println!("cargo:rustc-link-arg=-Wl,-rpath={rpath}");
}

fn link_libgl() {
    // libflutter_engine.so uses libGL.so, not the Rust code.
    // rustc has no idea and thinks libGL.so is not needed.
    // --no-as-needed is needed to force the linker to link libGL.so.
    // We manually put -lGL here because `println!("cargo:rustc-link-lib=GL")` doesn't work.
    println!("cargo:rustc-link-arg=-Wl,--no-as-needed,-lGL");
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
