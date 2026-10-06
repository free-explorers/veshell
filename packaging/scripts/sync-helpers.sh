#!/usr/bin/env bash
# sync-helpers.sh - copy the canonical build helper into each recipe.
#
# The Arch, Fedora and Debian recipes each ship a self-contained copy of
# scripts/build-veshell.sh (distribution submissions cannot reach outside their
# own directory). Run this after editing the canonical script, then refresh the
# build-veshell.sh checksum in packaging/arch/PKGBUILD (updpkgsums).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/scripts/build-veshell.sh"

for recipe in arch fedora debian; do
  install -m755 "$src" "$root/$recipe/build-veshell.sh"
  printf 'synced %s/build-veshell.sh\n' "$recipe"
done
