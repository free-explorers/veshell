#!/usr/bin/env bash
# generate-inputs.sh - regenerate the pinned, generated packaging inputs.
#
# The distribution recipes consume two generated, checksummed inputs in
# addition to the upstream Flutter artifacts:
#
#   veshell-cargo-vendor-<release>.tar.zst   `cargo vendor` tree (offline Rust)
#   veshell-pubcache-<release>.tar.zst       Dart pub cache (offline pub get)
#
# `<release>` is the release id from packaging/release.json (for example
# 0.2.0-beta.1). Run this from a Veshell checkout that already has a working
# Flutter SDK (normally .flutter_sdk, created by `cargo run`). It needs network
# access to populate the pub cache; the produced archives are then used
# offline.
#
# Usage:
#   packaging/scripts/generate-inputs.sh [all|vendor|pubcache|verify]
#
# After regenerating, update the sha256 values in packaging/release.json and
# re-render the recipes with packaging/scripts/render-recipes.py.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$script_dir/.." && pwd)"
VESHELL_SRC="${VESHELL_SRC:-$(cd "$root/.." && pwd)}"
OUT_DIR="${VESHELL_INPUT_OUT:-$root/dist}"
MANIFEST="${VESHELL_MANIFEST:-$root/release.json}"
FLUTTER_SDK_DIR="${FLUTTER_SDK_DIR:-$VESHELL_SRC/.flutter_sdk}"

[[ -f "$MANIFEST" ]] || { printf 'error: manifest not found: %s\n' "$MANIFEST" >&2; exit 1; }

log() { printf '\n==> %s\n' "$*" >&2; }

json_get() {
  python3 - "$MANIFEST" "$1" <<'PY'
import json, sys
node = json.load(open(sys.argv[1]))
for part in sys.argv[2].split("."):
    node = node[part]
print("" if node is None else node)
PY
}

VERSION="$(json_get version)"
PRERELEASE="$(json_get prerelease)"
RELEASE_ID="$VERSION"
[[ -n "$PRERELEASE" ]] && RELEASE_ID="$VERSION-$PRERELEASE"

make_tarball() {
  local src="$1" out="$2"
  tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
      -C "$src" -cf - . | zstd -19 -T0 -q -o "$out"
}

gen_vendor() {
  log "Generating Cargo vendor tree -> $(basename "$OUT_DIR")/veshell-cargo-vendor-$RELEASE_ID.tar.zst"
  mkdir -p "$OUT_DIR"
  local work
  work="$(mktemp -d)"
  ( cd "$VESHELL_SRC" && cargo vendor "$work/vendor" >/dev/null )
  make_tarball "$work/vendor" "$OUT_DIR/veshell-cargo-vendor-$RELEASE_ID.tar.zst"
  rm -rf "$work"
  sha256sum "$OUT_DIR/veshell-cargo-vendor-$RELEASE_ID.tar.zst"
}

gen_pubcache() {
  log "Generating Dart pub cache -> $(basename "$OUT_DIR")/veshell-pubcache-$RELEASE_ID.tar.zst"
  [ -x "$FLUTTER_SDK_DIR/bin/flutter" ] || {
    printf 'error: no Flutter SDK at %s (run `cargo run` first or set FLUTTER_SDK_DIR)\n' \
      "$FLUTTER_SDK_DIR" >&2
    exit 1
  }
  mkdir -p "$OUT_DIR"
  local cache
  cache="$(mktemp -d)"
  rm -rf "$VESHELL_SRC/src/shell/.dart_tool"
  ( cd "$VESHELL_SRC/src/shell"
    PUB_CACHE="$cache" "$FLUTTER_SDK_DIR/bin/flutter" pub get )
  make_tarball "$cache" "$OUT_DIR/veshell-pubcache-$RELEASE_ID.tar.zst"
  rm -rf "$cache"
  sha256sum "$OUT_DIR/veshell-pubcache-$RELEASE_ID.tar.zst"
}

verify_upstream() {
  log "Verifying pinned upstream artifacts"
  local work pairs sha url file got failed=0
  work="$(mktemp -d)"
  pairs="$(mktemp)"
  trap 'rm -rf "$work"; rm -f "$pairs"' RETURN

  python3 - "$MANIFEST" > "$pairs" <<'PY'
import json, sys

def walk(node):
    if isinstance(node, dict):
        if "url" in node and "sha256" in node:
            yield node["sha256"], node["url"]
            return
        for value in node.values():
            yield from walk(value)
    elif isinstance(node, list):
        for value in node:
            yield from walk(value)

for sha, url in walk(json.load(open(sys.argv[1]))):
    print(sha, url)
PY

  while read -r sha url; do
    [ -n "$url" ] || continue
    file="$work/${url##*/}"
    curl -fsSL -o "$file" "$url"
    got="$(sha256sum "$file" | cut -d' ' -f1)"
    if [ "$got" = "$sha" ]; then
      printf 'ok   %s\n' "${url##*/}"
    else
      printf 'FAIL %s\n  want %s\n  got  %s\n' "${url##*/}" "$sha" "$got" >&2
      failed=1
    fi
  done < "$pairs"
  return "$failed"
}

case "${1:-all}" in
  all)      gen_vendor; gen_pubcache ;;
  vendor)   gen_vendor ;;
  pubcache) gen_pubcache ;;
  verify)   verify_upstream ;;
  *) printf 'usage: %s [all|vendor|pubcache|verify]\n' "$0" >&2; exit 2 ;;
esac
