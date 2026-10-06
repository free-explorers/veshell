#!/usr/bin/env bash
# obs-publish.sh - upload a rendered binary package to the Open Build Service.
#
# The binary recipe is small, so its sources are uploaded directly. The source
# package (Flutter's ~1.9 GB of pinned inputs) is not handled here: it needs a
# server-side _service or the sources hosted where OBS can fetch them.
#
# Environment:
#   OSC_CONFIG   path to an oscrc holding the apiurl and credentials
#
# Usage: obs-publish.sh SPEC_DIR OBS_PROJECT OBS_PACKAGE [--dry-run]
#   SPEC_DIR must contain veshell-bin.spec, veshell-bin.changes and the prebuilt
#   tarball named after the spec's Source0 URL basename.
#   The OBS package must already exist; create it once in the OBS web UI.
set -euo pipefail

spec_dir="${1:?usage: obs-publish.sh SPEC_DIR OBS_PROJECT OBS_PACKAGE [--dry-run]}"
project="${2:?usage: obs-publish.sh SPEC_DIR OBS_PROJECT OBS_PACKAGE [--dry-run]}"
package="${3:?usage: obs-publish.sh SPEC_DIR OBS_PROJECT OBS_PACKAGE [--dry-run]}"
dry_run=0
[[ "${4:-}" == "--dry-run" ]] && dry_run=1

[[ -f "$spec_dir/veshell-bin.spec" ]] || { printf 'error: missing %s/veshell-bin.spec\n' "$spec_dir" >&2; exit 1; }
[[ -n "${OSC_CONFIG:-}" ]] || { printf 'error: OSC_CONFIG is not set\n' >&2; exit 1; }
command -v osc >/dev/null || { printf 'error: osc is required\n' >&2; exit 1; }

osc() { command osc -c "$OSC_CONFIG" "$@"; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if ! osc checkout "$project" "$package" "$work/pkg"; then
  printf 'error: OBS package %s/%s is not reachable; create it first\n' "$project" "$package" >&2
  exit 1
fi

# Replace the tracked sources with this release's.
find "$work/pkg" -maxdepth 1 -type f ! -name '.*' -delete
cp "$spec_dir"/veshell-bin.spec "$spec_dir"/veshell-bin.changes "$work/pkg/"
for asset in "$spec_dir"/veshell-*.tar.zst; do
  [[ -e "$asset" ]] && cp "$asset" "$work/pkg/"
done
( cd "$work/pkg" && osc addremove )

version="$(awk -F': *' '/^Version:/{print $2; exit}' "$spec_dir/veshell-bin.spec")"
release="$(awk -F': *' '/^Release:/{print $2; exit}' "$spec_dir/veshell-bin.spec")"

if ((dry_run)); then
  printf 'dry run: osc package %s/%s would be committed\n' "$project" "$package"
  ( cd "$work/pkg" && osc status )
  exit 0
fi

( cd "$work/pkg" && osc commit -m "Update veshell-bin to ${version}-${release}" )
printf 'committed %s/%s\n' "$project" "$package"
