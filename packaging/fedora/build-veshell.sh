#!/usr/bin/env bash
# build-veshell.sh - hermetic, offline source build of Veshell.
#
# Veshell is a Rust compositor plus a Flutter/Dart shell. This helper mirrors
# the project's documented offline packaging contract (see docs/building.md):
# the Flutter shell is compiled from Dart sources against the pinned Flutter
# SDK and engine artifacts, then the Rust compositor is compiled against the
# resulting bundle with vendored crates and no network access.
#
# It is shared by every distribution recipe under packaging/. Nothing here
# downloads anything: all inputs are supplied as already-verified sources.
#
# Environment for "build" / "all":
#   FLUTTER_SDK_DIR        extracted official Flutter SDK (contains bin/flutter)
#   FLUTTER_ARTIFACT_DIR   directory holding the pinned engine artifact zips:
#                            flutter_patched_sdk.zip
#                            flutter_patched_sdk_product.zip
#                            linux-x64_artifacts.zip
#                            linux-x64-debug_flutter-gtk.zip
#                            linux-x64-profile_flutter-gtk.zip
#                            linux-x64-release_flutter-gtk.zip
#   ENGINE_TARBALL         meta-flutter engine-sdk tarball (matching revision)
#   CARGO_VENDOR_DIR       extracted `cargo vendor` tree
#   PUB_CACHE_DIR          pre-populated Dart pub cache (used as PUB_CACHE)
#
# Common environment:
#   VESHELL_SRC            Veshell source tree (default: current directory)
#   PREFIX                 final installation prefix (default: /usr)
#   DESTDIR                staging root for install (required by "install")
#   POLKIT_HELPER_PATH     polkit helper baked into the shell
#                          (default: /usr/lib/polkit-1/polkit-agent-helper-1)
#   JOBS                   parallelism (default: number of CPUs)
#   VESHELL_FLUTTER_ARCH   Flutter target directory (default: host: x64|arm64)
#
# Commands:
#   build     compile the Dart shell and the Rust compositor
#   install   stage the built payload under DESTDIR via the project Makefile
#   all       build then install
set -euo pipefail

log() { printf '\n==> %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

VESHELL_SRC="${VESHELL_SRC:-$(pwd)}"
PREFIX="${PREFIX:-/usr}"
POLKIT_HELPER_PATH="${POLKIT_HELPER_PATH:-/usr/lib/polkit-1/polkit-agent-helper-1}"
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}"

case "$(uname -m)" in
  x86_64)  VESHELL_FLUTTER_ARCH="${VESHELL_FLUTTER_ARCH:-x64}" ;;
  aarch64) VESHELL_FLUTTER_ARCH="${VESHELL_FLUTTER_ARCH:-arm64}" ;;
  *) die "unsupported host architecture: $(uname -m)" ;;
esac

ENGINE_ROOT="$VESHELL_SRC/extra/third_party/flutter_engine"
SHELL_BUNDLE="$VESHELL_SRC/src/shell/build/linux/$VESHELL_FLUTTER_ARCH/release/bundle"

require_build_inputs() {
  : "${FLUTTER_SDK_DIR:?set FLUTTER_SDK_DIR to the extracted Flutter SDK}"
  : "${FLUTTER_ARTIFACT_DIR:?set FLUTTER_ARTIFACT_DIR to the engine artifact directory}"
  : "${ENGINE_TARBALL:?set ENGINE_TARBALL to the meta-flutter engine tarball}"
  : "${CARGO_VENDOR_DIR:?set CARGO_VENDOR_DIR to the extracted cargo vendor tree}"
  : "${PUB_CACHE_DIR:?set PUB_CACHE_DIR to the populated pub cache}"
  [ -x "$FLUTTER_SDK_DIR/bin/flutter" ] || die "Flutter SDK binary not found: $FLUTTER_SDK_DIR/bin/flutter"
  [ -d "$FLUTTER_ARTIFACT_DIR" ] || die "missing artifact dir: $FLUTTER_ARTIFACT_DIR"
  [ -f "$ENGINE_TARBALL" ] || die "missing engine tarball: $ENGINE_TARBALL"
  [ -d "$CARGO_VENDOR_DIR" ] || die "missing cargo vendor tree: $CARGO_VENDOR_DIR"
  [ -d "$PUB_CACHE_DIR" ] || die "missing pub cache: $PUB_CACHE_DIR"
}

overlay_flutter_artifacts() {
  log "Overlaying pinned Flutter engine artifacts into the SDK cache"
  local eng="$FLUTTER_SDK_DIR/bin/cache/artifacts/engine"
  mkdir -p "$eng/common" "$eng/linux-$VESHELL_FLUTTER_ARCH" \
           "$eng/linux-$VESHELL_FLUTTER_ARCH-profile" \
           "$eng/linux-$VESHELL_FLUTTER_ARCH-release"
  unzip -qo "$FLUTTER_ARTIFACT_DIR/flutter_patched_sdk.zip"         -d "$eng/common"
  unzip -qo "$FLUTTER_ARTIFACT_DIR/flutter_patched_sdk_product.zip" -d "$eng/common"
  unzip -qo "$FLUTTER_ARTIFACT_DIR/linux-${VESHELL_FLUTTER_ARCH}_artifacts.zip" \
            -d "$eng/linux-$VESHELL_FLUTTER_ARCH"
  unzip -qo "$FLUTTER_ARTIFACT_DIR/linux-${VESHELL_FLUTTER_ARCH}-debug_flutter-gtk.zip" \
            -d "$eng/linux-$VESHELL_FLUTTER_ARCH"
  unzip -qo "$FLUTTER_ARTIFACT_DIR/linux-${VESHELL_FLUTTER_ARCH}-profile_flutter-gtk.zip" \
            -d "$eng/linux-$VESHELL_FLUTTER_ARCH-profile"
  unzip -qo "$FLUTTER_ARTIFACT_DIR/linux-${VESHELL_FLUTTER_ARCH}-release_flutter-gtk.zip" \
            -d "$eng/linux-$VESHELL_FLUTTER_ARCH-release"
}

stage_engine() {
  log "Staging the pinned Flutter embedder engine"
  rm -rf "$ENGINE_ROOT"
  local tmp sdk
  tmp="$(mktemp -d)"
  tar -xzf "$ENGINE_TARBALL" -C "$tmp"
  sdk="$(find "$tmp" -type d -path '*/out/*/engine-sdk' | head -n1)"
  [ -n "$sdk" ] || die "engine-sdk directory not found in $ENGINE_TARBALL"
  [ -f "$sdk/include/flutter_embedder.h" ] || die "flutter_embedder.h missing from engine"
  [ -f "$sdk/lib/libflutter_engine.so" ] || die "libflutter_engine.so missing from engine"
  mkdir -p "$ENGINE_ROOT/release"
  install -Dm644 "$sdk/include/flutter_embedder.h" "$ENGINE_ROOT/flutter_embedder.h"
  install -Dm755 "$sdk/lib/libflutter_engine.so"   "$ENGINE_ROOT/release/libflutter_engine.so"
  rm -rf "$tmp"
}

configure_cargo_vendor() {
  log "Configuring Cargo to build from vendored sources"
  mkdir -p "$VESHELL_SRC/.cargo"
  local cfg="$VESHELL_SRC/.cargo/config.toml"
  if ! grep -q 'vendored-sources' "$cfg" 2>/dev/null; then
    cat >> "$cfg" <<EOF

# Added by packaging/scripts/build-veshell.sh: build strictly offline.
[source.crates-io]
replace-with = "vendored-sources"

[source."git+https://github.com/Smithay/smithay.git?rev=4cf0b62028039661477d482ec4758b687d8f4392"]
git = "https://github.com/Smithay/smithay.git"
rev = "4cf0b62028039661477d482ec4758b687d8f4392"
replace-with = "vendored-sources"

[source.vendored-sources]
directory = "$CARGO_VENDOR_DIR"
EOF
  fi
}

build_shell() {
  log "Building the Dart shell from source (offline)"
  export PUB_CACHE="$PUB_CACHE_DIR"
  export PUB_ENVIRONMENT="veshell-packaging"
  export FLUTTER_SUPPRESS_ANALYTICS=true
  # pub get must not consult pub.dev; the cache is complete by construction.
  ( cd "$VESHELL_SRC/src/shell"
    "$FLUTTER_SDK_DIR/bin/flutter" --no-version-check config --no-analytics >/dev/null 2>&1 || true
    "$FLUTTER_SDK_DIR/bin/flutter" --no-version-check pub get --offline
    "$FLUTTER_SDK_DIR/bin/dart" run build_runner build
    "$FLUTTER_SDK_DIR/bin/flutter" --no-version-check build linux --release \
      --dart-define="VESHELL_POLKIT_HELPER_PATH=$POLKIT_HELPER_PATH"
  )
  [ -f "$SHELL_BUNDLE/lib/libapp.so" ] || die "shell AOT library missing: $SHELL_BUNDLE/lib/libapp.so"
}

build_rust() {
  log "Building the Rust compositor from source (offline)"
  (
    cd "$VESHELL_SRC"
    export VESHELL_PREBUILT_SHELL="$SHELL_BUNDLE"
    export VESHELL_ENGINE_DIR="$ENGINE_ROOT"
    export VESHELL_FLUTTER_MODE=release
    export VESHELL_LIB_DIR="$PREFIX/lib/veshell"
    export VESHELL_DATA_DIR="$PREFIX/share/veshell/data"
    export VESHELL_DEFAULT_CONFIG_DIR="$PREFIX/share/veshell/settings/default"
    export VESHELL_POLKIT_HELPER_PATH="$POLKIT_HELPER_PATH"
    export CARGO_NET_OFFLINE=true
    cargo build --locked --offline --release -j "$JOBS"
  )
}

install_payload() {
  : "${DESTDIR:?set DESTDIR for install}"
  log "Staging payload under $DESTDIR (final prefix $PREFIX)"
  (
    cd "$VESHELL_SRC"
    make install \
      PREFIX="$PREFIX" \
      DESTDIR="$DESTDIR" \
      PROFILE=release \
      FLUTTER_MODE=release \
      ARCH="$(uname -m)" \
      ASSETS_DIR="extra/assets" \
      SETTINGS_DIR="extra/settings"
  )
}

case "${1:-all}" in
  build)
    require_build_inputs
    overlay_flutter_artifacts; stage_engine; configure_cargo_vendor; build_shell; build_rust ;;
  install)
    install_payload ;;
  all)
    require_build_inputs
    overlay_flutter_artifacts; stage_engine; configure_cargo_vendor; build_shell; build_rust; install_payload ;;
  *) die "unknown command: $1 (expected build|install|all)" ;;
esac
