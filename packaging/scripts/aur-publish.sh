#!/usr/bin/env bash
# aur-publish.sh - publish a rendered package to the Arch User Repository.
#
# Clones (or initialises) the AUR git repository for PACKAGE, copies the
# PKGBUILD and .SRCINFO from SOURCE_DIR, commits, and pushes over SSH.
#
# The AUR package must already exist (create it once in the AUR web UI); a
# first ever push to a non-existent package is rejected by the AUR.
#
# Environment:
#   AUR_SSH_KEY    path to the SSH private key authorized for your AUR account
#   AUR_GIT_NAME   commit author name  (default: Veshell release bot)
#   AUR_GIT_EMAIL  commit author email (default: releases@veshell.invalid)
#   AUR_GIT_BASE   git base URL (default: ssh://aur@aur.archlinux.org); useful
#                  for local testing against a bare repository
#
# Usage: aur-publish.sh PACKAGE SOURCE_DIR [--dry-run]
set -euo pipefail

package="${1:?usage: aur-publish.sh PACKAGE SOURCE_DIR [--dry-run]}"
source_dir="${2:?usage: aur-publish.sh PACKAGE SOURCE_DIR [--dry-run]}"
dry_run=0
[[ "${3:-}" == "--dry-run" ]] && dry_run=1

[[ -f "$source_dir/PKGBUILD" ]] || { printf 'error: missing %s/PKGBUILD\n' "$source_dir" >&2; exit 1; }
[[ -f "$source_dir/.SRCINFO" ]] || { printf 'error: missing %s/.SRCINFO\n' "$source_dir" >&2; exit 1; }

git_name="${AUR_GIT_NAME:-Veshell release bot}"
git_email="${AUR_GIT_EMAIL:-releases@veshell.invalid}"

work="$(mktemp -d)"
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

if [[ -n "${AUR_SSH_KEY:-}" ]]; then
  export GIT_SSH_COMMAND="ssh -i $AUR_SSH_KEY -o StrictHostKeyChecking=accept-new"
fi

remote="${AUR_GIT_BASE:-ssh://aur@aur.archlinux.org}/$package.git"
if git ls-remote "$remote" >/dev/null 2>&1; then
  git clone --depth=1 "$remote" "$work/$package"
else
  printf 'note: AUR repository %s is not reachable yet; assuming it exists and is empty\n' "$package" >&2
  git init -q "$work/$package"
  git -C "$work/$package" remote add origin "$remote"
fi

install -m644 "$source_dir/PKGBUILD" "$work/$package/PKGBUILD"
install -m644 "$source_dir/.SRCINFO" "$work/$package/.SRCINFO"

git -C "$work/$package" add PKGBUILD .SRCINFO
if git -C "$work/$package" diff --cached --quiet; then
  printf '%s: no changes to publish\n' "$package"
  exit 0
fi

if ((dry_run)); then
  printf '%s: dry run, would publish:\n' "$package"
  git -C "$work/$package" --no-pager diff --cached --stat
  exit 0
fi

git -C "$work/$package" \
  -c user.name="$git_name" -c user.email="$git_email" \
  commit -m "Update to $(grep -m1 '^pkgver=' "$source_dir/PKGBUILD" | cut -d= -f2)"

git -C "$work/$package" push origin HEAD:master
printf '%s: pushed\n' "$package"
