#!/usr/bin/env bash
# copr-publish.sh - build an SRPM from a rendered spec and submit it to COPR.
#
# The binary recipe is small (the prebuilt payload), so a self-contained SRPM is
# well within COPR's upload limits. The source recipe is not submitted here:
# Flutter's ~1.9 GB of pinned inputs must be fetched builder-side instead.
#
# Environment:
#   COPR_CONFIG   path to a copr-cli config file ([copr-cli] login/username/token)
#
# Usage: copr-publish.sh SPEC_DIR COPR_PROJECT [--dry-run]
#   SPEC_DIR must contain veshell-bin.spec and the prebuilt tarball named after
#   its Source0 URL basename.
set -euo pipefail

spec_dir="${1:?usage: copr-publish.sh SPEC_DIR COPR_PROJECT [--dry-run]}"
project="${2:?usage: copr-publish.sh SPEC_DIR COPR_PROJECT [--dry-run]}"
dry_run=0
[[ "${3:-}" == "--dry-run" ]] && dry_run=1

spec="$spec_dir/veshell-bin.spec"
[[ -f "$spec" ]] || { printf 'error: missing %s\n' "$spec" >&2; exit 1; }
[[ -n "${COPR_CONFIG:-}" ]] || { printf 'error: COPR_CONFIG is not set\n' >&2; exit 1; }
command -v rpmbuild >/dev/null || { printf 'error: rpmbuild is required\n' >&2; exit 1; }
command -v copr-cli >/dev/null || { printf 'error: copr-cli is required\n' >&2; exit 1; }

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

rpmbuild -bs "$spec" \
  --define "_sourcedir $spec_dir" \
  --define "_srcrpmdir $out" \
  --define "_builddir $out/BUILD" \
  --define "_rpmdir $out/RPMS" \
  --define "_buildrootdir $out/BUILDROOT" \
  --define "_tmppath $out/tmp"

srpm="$(find "$out" -maxdepth 1 -name '*.src.rpm' -print -quit)"
[[ -n "$srpm" ]] || { printf 'error: no SRPM was produced\n' >&2; exit 1; }
printf 'built %s\n' "$srpm"

if ((dry_run)); then
  printf 'dry run: copr-cli --config %s build %s %s\n' "$COPR_CONFIG" "$project" "$srpm"
  exit 0
fi

copr-cli --config "$COPR_CONFIG" build "$project" "$srpm"
