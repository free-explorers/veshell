#!/usr/bin/env bash
# fetch-inputs.sh - download and verify every pinned packaging input.
#
# Produces the layout that packaging/scripts/build-veshell.sh consumes:
#
#   DEST/flutter-sdk/        extracted official Flutter SDK
#   DEST/artifacts/          the six engine artifact zips (canonical names)
#   DEST/engine.tar.gz       meta-flutter embedder engine tarball
#   DEST/cargo-vendor/       extracted `cargo vendor` tree
#   DEST/pubcache/           extracted Dart pub cache
#
# URLs and hashes come from packaging/release.json. The two generated inputs
# are fetched from mirrors.inputs as veshell-<release>-*.tar.zst.
#
# Usage: fetch-inputs.sh DEST
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$script_dir/.." && pwd)"
manifest="${VESHELL_MANIFEST:-$root/release.json}"

dest="${1:?usage: fetch-inputs.sh DEST}"
[[ -f "$manifest" ]] || { printf 'error: manifest not found: %s\n' "$manifest" >&2; exit 1; }

log() { printf '==> %s\n' "$*" >&2; }

readarray -t meta < <(python3 - "$manifest" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
version = m["version"]
pre = m.get("prerelease")
release_id = f"{version}-{pre}" if pre else version
fv = m["flutter"]["version"]
rev = m["flutter"]["engine_revision"]
inputs = m["mirrors"]["inputs"]
rows = [
    ("sdk", m["flutter"]["sdk"]["url"], m["flutter"]["sdk"]["sha256"], f"flutter_linux_{fv}-stable.tar.xz"),
    ("patched_sdk", m["flutter"]["artifacts"]["patched_sdk"]["url"], m["flutter"]["artifacts"]["patched_sdk"]["sha256"], "flutter_patched_sdk.zip"),
    ("patched_sdk_product", m["flutter"]["artifacts"]["patched_sdk_product"]["url"], m["flutter"]["artifacts"]["patched_sdk_product"]["sha256"], "flutter_patched_sdk_product.zip"),
    ("linux_x64_artifacts", m["flutter"]["artifacts"]["linux_x64_artifacts"]["url"], m["flutter"]["artifacts"]["linux_x64_artifacts"]["sha256"], "linux-x64_artifacts.zip"),
    ("linux_x64_debug_gtk", m["flutter"]["artifacts"]["linux_x64_debug_gtk"]["url"], m["flutter"]["artifacts"]["linux_x64_debug_gtk"]["sha256"], "linux-x64-debug_flutter-gtk.zip"),
    ("linux_x64_profile_gtk", m["flutter"]["artifacts"]["linux_x64_profile_gtk"]["url"], m["flutter"]["artifacts"]["linux_x64_profile_gtk"]["sha256"], "linux-x64-profile_flutter-gtk.zip"),
    ("linux_x64_release_gtk", m["flutter"]["artifacts"]["linux_x64_release_gtk"]["url"], m["flutter"]["artifacts"]["linux_x64_release_gtk"]["sha256"], "linux-x64-release_flutter-gtk.zip"),
    ("engine", m["flutter"]["engine"]["url"], m["flutter"]["engine"]["sha256"], f"linux-engine-sdk-release-x86_64-{rev}.tar.gz"),
    ("cargo_vendor", f"{inputs}/veshell-cargo-vendor-{release_id}.tar.zst", m["inputs"]["cargo_vendor"]["sha256"], f"veshell-cargo-vendor-{release_id}.tar.zst"),
    ("pubcache", f"{inputs}/veshell-pubcache-{release_id}.tar.zst", m["inputs"]["pubcache"]["sha256"], f"veshell-pubcache-{release_id}.tar.zst"),
]
for kind, url, sha, name in rows:
    print("\t".join((kind, url, sha, name)))
PY
)

downloads="$dest/.downloads"
mkdir -p "$downloads" "$dest/artifacts"

verify() {
  local file="$1" want="$2"
  local got
  got="$(sha256sum "$file" | cut -d' ' -f1)"
  if [[ "$got" != "$want" ]]; then
    printf 'error: checksum mismatch for %s\n  want %s\n  got  %s\n' "$file" "$want" "$got" >&2
    return 1
  fi
}

fetch() {
  local url="$1" want="$2" out="$3"
  if [[ -f "$out" ]] && verify "$out" "$want" 2>/dev/null; then
    printf 'cached %s\n' "$(basename "$out")"
    return 0
  fi
  log "fetching $(basename "$out")"
  curl -fsSL --retry 3 -o "$out.part" "$url"
  verify "$out.part" "$want"
  mv "$out.part" "$out"
}

# Download everything first.
declare -A KIND_NAME KIND_SHA
for row in "${meta[@]}"; do
  IFS=$'\t' read -r kind url sha name <<<"$row"
  KIND_NAME[$kind]="$name"
  KIND_SHA[$kind]="$sha"
  fetch "$url" "$sha" "$downloads/$name"
done

# Lay the inputs out for build-veshell.sh.
log "extracting Flutter SDK"
rm -rf "$dest/flutter-sdk"
mkdir -p "$dest/flutter-sdk"
tar -xJf "$downloads/${KIND_NAME[sdk]}" -C "$dest/flutter-sdk" --strip-components=1

for kind in patched_sdk patched_sdk_product linux_x64_artifacts linux_x64_debug_gtk linux_x64_profile_gtk linux_x64_release_gtk; do
  install -m644 "$downloads/${KIND_NAME[$kind]}" "$dest/artifacts/${KIND_NAME[$kind]}"
done

install -m644 "$downloads/${KIND_NAME[engine]}" "$dest/engine.tar.gz"

log "extracting Cargo vendor tree"
rm -rf "$dest/cargo-vendor"
mkdir -p "$dest/cargo-vendor"
tar -xf "$downloads/${KIND_NAME[cargo_vendor]}" -C "$dest/cargo-vendor"

log "extracting pub cache"
rm -rf "$dest/pubcache"
mkdir -p "$dest/pubcache"
tar -xf "$downloads/${KIND_NAME[pubcache]}" -C "$dest/pubcache"

printf '\ninputs ready in %s\n' "$dest"
printf '  FLUTTER_SDK_DIR=%s\n' "$dest/flutter-sdk"
printf '  FLUTTER_ARTIFACT_DIR=%s\n' "$dest/artifacts"
printf '  ENGINE_TARBALL=%s\n' "$dest/engine.tar.gz"
printf '  CARGO_VENDOR_DIR=%s\n' "$dest/cargo-vendor"
printf '  PUB_CACHE_DIR=%s\n' "$dest/pubcache"
