#!/usr/bin/env bash
# prebuilt-in-container.sh - build the prebuilt payload inside archlinux.
#
# Invoked by .github/workflows/release.yml via:
#   docker run --rm -v "$GITHUB_WORKSPACE:/work" -w /work archlinux:base-devel \
#     bash /work/packaging/ci/prebuilt-in-container.sh
#
# It installs the Arch build dependencies, fetches and verifies every pinned
# input, then builds out/veshell-<release>-x86_64.tar.zst and out/SHA256SUMS.
set -euo pipefail

work="${1:-/work}"
cd "$work"

if ! command -v pacman >/dev/null; then
  printf 'error: this script must run inside an Arch Linux container\n' >&2
  exit 1
fi

pacman-key --init
pacman-key --populate archlinux

mapfile -t packages < <(grep -vE '^[[:space:]]*(#|$)' packaging/ci/arch-deps.txt)
pacman -Syu --noconfirm --needed "${packages[@]}"

rm -rf "$work/.inputs"
packaging/scripts/fetch-inputs.sh "$work/.inputs"

rm -rf "$work/out"
packaging/scripts/build-prebuilt.sh "$work/.inputs" "$work/out"

ls -la "$work/out"
