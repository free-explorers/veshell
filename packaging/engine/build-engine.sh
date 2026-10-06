#!/usr/bin/env bash
# build-engine.sh - build a portable Flutter engine SDK from source.
#
# This mirrors the Linux x86_64 build in meta-flutter/flutter-engine (Apache-2.0;
# see README.md for provenance). It produces the same artifact contract as the
# meta-flutter releases:
#
#   linux-engine-sdk-<mode>-x86_64-<revision>.tar.gz
#   linux-engine-sdk-<mode>-x86_64-<revision>.tar.gz.sha256
#
# The tarball contains flutter/engine/src/out/<out>/engine-sdk/{include,lib},
# which is what Veshell's dev build and packaging/scripts/build-veshell.sh read.
# It is built against the Debian bullseye sysroot so it runs on Debian/Fedora,
# unlike the Nix engine build (whose outputs are patched to the Nix loader).
#
# Usage: build-engine.sh MODE REVISION OUT_DIR [WORK_DIR]
#   MODE      release | debug | profile | debug-unopt
#   REVISION  Flutter engine revision (SDK bin/internal/engine.version)
#   OUT_DIR   where the tarball and .sha256 are written
#   WORK_DIR  scratch checkout (default: $PWD/engine-build)
set -euo pipefail

mode="${1:?usage: build-engine.sh MODE REVISION OUT_DIR [WORK_DIR]}"
revision="${2:?usage: build-engine.sh MODE REVISION OUT_DIR [WORK_DIR]}"
out_dir="${3:?usage: build-engine.sh MODE REVISION OUT_DIR [WORK_DIR]}"
work="${4:-$PWD/engine-build}"
script_dir="$(cd "$(dirname "$0")" && pwd)"

arch=x64
linux_cpu=x64
target_triple=x86_64-unknown-linux-gnu
target_sysroot=debian_bullseye_amd64-sysroot

case "$mode" in
  release)     gn_mode=release; out_name=linux_release_x64 ;;
  debug)       gn_mode=debug;   out_name=linux_debug_x64 ;;
  profile)     gn_mode=profile; out_name=linux_profile_x64 ;;
  debug-unopt) gn_mode=debug;   out_name=linux_debug_unopt_x64 ;;
  *) printf 'unknown mode: %s\n' "$mode" >&2; exit 2 ;;
esac

asset="linux-engine-sdk-${mode}-x86_64-${revision}"
mkdir -p "$out_dir" "$work"
out_dir="$(cd "$out_dir" && pwd)"
work="$(cd "$work" && pwd)"
engine_src="$work/flutter/engine/src"
sdk_rel="flutter/engine/src/out/${out_name}/engine-sdk"

log() { printf '\n==> %s\n' "$*" >&2; }

log "Preparing depot_tools"
if [[ ! -d "$work/depot_tools" ]]; then
  git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$work/depot_tools"
fi
export PATH="$work/depot_tools:$PATH"
export VPYTHON_VIRTUALENV_ROOT="$work/vpython"

log "Syncing the Flutter engine sources at $revision"
if [[ ! -d "$work/flutter" ]]; then
  git clone --depth 1 https://github.com/flutter/flutter.git "$work/flutter"
fi
(
  cd "$work/flutter"
  gclient config --spec 'solutions=[{"managed":False,"name":".","url":"https://github.com/flutter/flutter.git","custom_deps":{},"custom_vars":{"download_android_deps":False,"download_windows_deps":False,"download_linux_deps":True},"deps_file":"DEPS","safesync_url":""}]'
  gclient sync --force --shallow --no-history -R -D --revision "$revision" -j"$(nproc)" -v
)

log "Installing the $target_sysroot sysroot"
(
  cd "$engine_src"
  build/linux/sysroot_scripts/install-sysroot.py --arch="$arch"
)

log "Applying the clang toolchain patch"
patch_file="$script_dir/patches/0001-clang-toolchain.patch"
if ! ( cd "$work/flutter" && git apply "$patch_file" ); then
  if ( cd "$work/flutter" && git apply --reverse --check "$patch_file" ); then
    log "clang toolchain patch already applied"
  else
    printf 'error: could not apply %s\n' "$patch_file" >&2
    exit 1
  fi
fi

log "Configuring the $gn_mode build"
(
  cd "$engine_src"
  clang_root="$(find . -iname clang++ -print -quit)"
  [[ -n "$clang_root" ]] || { printf 'clang++ not found after sync\n' >&2; exit 1; }
  clang_root="$(dirname "$clang_root")"
  clang_root="$(dirname "$clang_root")"
  gn_args=(
    "--runtime-mode=$gn_mode"
    --embedder-for-target
    --no-build-embedder-examples
    --no-goma --no-rbe
    --no-stripped --no-enable-unittests
    --no-dart-version-git-info
    --linux-cpu "$linux_cpu"
    --target-os linux
    --target-sysroot "$PWD/build/linux/$target_sysroot"
    --target-toolchain "$PWD/$clang_root"
    --target-triple "$target_triple"
  )
  [[ "$mode" == debug-unopt ]] && gn_args+=(--unoptimized)
  ./flutter/tools/gn "${gn_args[@]}"
  ninja -C "out/$out_name"
)

log "Packaging the SDK"
sdk_dir="$work/$sdk_rel"
rm -rf "$sdk_dir"
mkdir -p "$sdk_dir/include" "$sdk_dir/lib"
if [[ -f "$engine_src/out/$out_name/flutter_embedder.h" ]]; then
  cp "$engine_src/out/$out_name/flutter_embedder.h" "$sdk_dir/include/flutter_embedder.h"
else
  cp "$engine_src/flutter/shell/platform/embedder/embedder.h" "$sdk_dir/include/flutter_embedder.h"
fi
cp "$engine_src/out/$out_name/libflutter_engine.so" "$sdk_dir/lib/"
test -s "$sdk_dir/include/flutter_embedder.h"
test -s "$sdk_dir/lib/libflutter_engine.so"

tar -C "$work" -czf "$out_dir/$asset.tar.gz" "$sdk_rel/"
(
  cd "$out_dir"
  sha256sum -b "$asset.tar.gz" > "$asset.tar.gz.sha256"
)
log "Wrote $out_dir/$asset.tar.gz"
cat "$out_dir/$asset.tar.gz.sha256"
