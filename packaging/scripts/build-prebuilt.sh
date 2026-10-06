#!/usr/bin/env bash
# build-prebuilt.sh - build the distro-agnostic prebuilt payload.
#
# Runs the shared hermetic build (packaging/scripts/build-veshell.sh) against the
# inputs prepared by fetch-inputs.sh, stages the payload with the project
# Makefile, and packs it as a plain tarball for the GitHub release:
#
#   OUT/veshell-<release>-x86_64.tar.zst   payload rooted at usr/...
#   OUT/SHA256SUMS                          sha256 of the payload tarball
#
# The tarball is the source for the AUR `veshell-bin` package and for users on
# non-Arch distributions. It is not distro-repackaged: recipes still build from
# source.
#
# Usage: build-prebuilt.sh INPUTS_DIR OUT_DIR
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$script_dir/.." && pwd)"
manifest="${VESHELL_MANIFEST:-$root/release.json}"
helper="$root/scripts/build-veshell.sh"

VESHELL_SRC="${VESHELL_SRC:-$(cd "$root/.." && pwd)}"

inputs="${1:?usage: build-prebuilt.sh INPUTS_DIR OUT_DIR}"
out="${2:?usage: build-prebuilt.sh INPUTS_DIR OUT_DIR}"

[[ -f "$manifest" ]] || { printf 'error: manifest not found: %s\n' "$manifest" >&2; exit 1; }

release_id="$(python3 - "$manifest" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
pre = m.get("prerelease")
print(f"{m['version']}-{pre}" if pre else m["version"])
PY
)"

export FLUTTER_SDK_DIR="$inputs/flutter-sdk"
export FLUTTER_ARTIFACT_DIR="$inputs/artifacts"
export ENGINE_TARBALL="$inputs/engine.tar.gz"
export CARGO_VENDOR_DIR="$inputs/cargo-vendor"
export PUB_CACHE_DIR="$inputs/pubcache"
export VESHELL_SRC

staging="$(mktemp -d)"
cleanup() { rm -rf "$staging"; }
trap cleanup EXIT

export PREFIX=/usr

bash "$helper" build
DESTDIR="$staging" bash "$helper" install

[[ -x "$staging/usr/bin/veshell" ]] || {
  printf 'error: payload is missing usr/bin/veshell\n' >&2
  exit 1
}
install -Dm644 "$VESHELL_SRC/LICENSE" "$staging/usr/share/licenses/veshell/LICENSE"

mkdir -p "$out"
tarball="$out/veshell-$release_id-x86_64.tar.zst"
rm -f "$tarball"
tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -C "$staging" -cf - . | zstd -19 -T0 -q -o "$tarball"

( cd "$out" && sha256sum "$(basename "$tarball")" > SHA256SUMS )
cat "$out/SHA256SUMS"
printf 'prebuilt payload: %s\n' "$tarball"
