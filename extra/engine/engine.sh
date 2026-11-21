#!/usr/bin/env bash
# engine.sh - check out, patch and build the Flutter engine locally.
#
# Veshell normally links a prebuilt engine downloaded for the pinned Flutter
# revision. This script supports working on the engine itself: it keeps a
# checkout of the Flutter monorepo on a `veshell/<flutter_version>` branch,
# based on the exact engine revision of the pinned SDK, and builds the
# embedder library from it incrementally.
#
# Usage: extra/engine/engine.sh COMMAND [ARGS]
#
#   sync              Fetch depot_tools and the Flutter sources, create the
#                     fork branch at the pinned engine revision, and sync the
#                     engine dependencies (tens of GB, a long first run).
#   build [VARIANT]   Configure (once) and build the embedder library.
#                     VARIANT: debug_unopt (default), debug, profile, release.
#   env [VARIANT]     Print the export that makes Cargo link that build.
#
# The checkout lives outside this repository, in ../veshell-engine by default;
# set VESHELL_ENGINE_WORKDIR to put it elsewhere. Cargo picks a local build up
# through VESHELL_LOCAL_ENGINE (see docs/building.md).
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
work="${VESHELL_ENGINE_WORKDIR:-$(dirname "$repo")/veshell-engine}"
flutter="$work/flutter"
src="$flutter/engine/src"

log() { printf '\n==> %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# The pin lives in Cargo.toml; the SDK checkout records the engine revision
# that this Flutter version was built from.
flutter_version() {
  sed -n 's/^flutter_version *= *"\(.*\)"/\1/p' "$repo/Cargo.toml"
}
engine_revision() {
  local file="$repo/.flutter_sdk/bin/internal/engine.version"
  [[ -s "$file" ]] || die "$file is missing: run \`cargo check\` once to install the pinned SDK"
  tr -d '[:space:]' < "$file"
}

use_depot_tools() {
  export PATH="$work/depot_tools:$PATH"
  export VPYTHON_VIRTUALENV_ROOT="$work/vpython"
  # depot_tools must not update itself in the middle of a build.
  export DEPOT_TOOLS_UPDATE=0
}

out_name() {
  case "${1:-debug_unopt}" in
    debug_unopt) echo host_debug_unopt ;;
    debug)       echo host_debug ;;
    profile)     echo host_profile ;;
    release)     echo host_release ;;
    *) die "unknown variant: $1 (debug_unopt, debug, profile or release)" ;;
  esac
}

cmd_sync() {
  local version revision branch
  version="$(flutter_version)"
  revision="$(engine_revision)"
  branch="veshell/$version"
  mkdir -p "$work"

  if [[ ! -d "$work/depot_tools" ]]; then
    log "Fetching depot_tools"
    git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git \
      "$work/depot_tools"
  fi
  use_depot_tools
  # With self-updates off, depot_tools never installs its own Python, and its
  # wrappers (ninja among them) refuse to run until it is there. A failure
  # after the Python install (an optional LUCI login tool) is harmless.
  if [[ ! -f "$work/depot_tools/python3_bin_reldir.txt" ]]; then
    log "Bootstrapping depot_tools"
    "$work/depot_tools/ensure_bootstrap" || true
    [[ -f "$work/depot_tools/python3_bin_reldir.txt" ]] || die "depot_tools bootstrap failed"
  fi

  if [[ ! -d "$flutter/.git" ]]; then
    # A blobless clone keeps the whole history (needed to rebase the fork
    # onto later releases) without downloading every past file version.
    log "Cloning the Flutter monorepo"
    git clone --filter=blob:none --no-checkout https://github.com/flutter/flutter.git "$flutter"
  fi

  if git -C "$flutter" rev-parse --verify --quiet "refs/heads/$branch" >/dev/null; then
    log "Fork branch $branch already exists; leaving it as it is"
    git -C "$flutter" merge-base --is-ancestor "$revision" "$branch" ||
      printf 'warning: %s does not contain the pinned engine revision %s\n' "$branch" "$revision" >&2
  else
    log "Creating $branch at engine revision $revision"
    git -C "$flutter" fetch origin "$revision"
    git -C "$flutter" branch "$branch" "$revision"
  fi
  # A fresh --no-checkout clone has no index yet, and nothing to lose.
  if [[ -f "$flutter/.git/index" &&
        -n "$(git -C "$flutter" status --porcelain --untracked-files=no)" ]]; then
    die "$flutter has uncommitted changes; commit or stash them before syncing"
  fi
  git -C "$flutter" checkout "$branch"

  # The root solution is unmanaged: gclient syncs the dependencies listed in
  # DEPS at the checked-out commit and never moves the fork branch.
  [[ -f "$flutter/.gclient" ]] || cp "$flutter/engine/scripts/standard.gclient" "$flutter/.gclient"
  log "Syncing the engine dependencies"
  # chromium.googlesource.com rate-limits (HTTP 429) a fetch per core.
  (cd "$flutter" && gclient sync -D --no-history -j"${VESHELL_ENGINE_SYNC_JOBS:-4}")
  log "Synced $branch in $flutter"
}

cmd_build() {
  local variant="${1:-debug_unopt}" out
  out="$(out_name "$variant")"
  [[ -d "$src/flutter" ]] || die "no engine checkout in $flutter: run \`$0 sync\` first"
  use_depot_tools

  if [[ ! -f "$src/out/$out/build.ninja" ]]; then
    local args=(--no-rbe --no-goma --no-enable-unittests --no-stripped)
    case "$variant" in
      debug_unopt) args+=(--runtime-mode=debug --unoptimized) ;;
      *)           args+=("--runtime-mode=$variant") ;;
    esac
    log "Configuring $out"
    (cd "$src" && ./flutter/tools/gn "${args[@]}")
  fi

  log "Building the embedder in $out"
  ninja -C "$src/out/$out" flutter/shell/platform/embedder:flutter_engine
  test -s "$src/out/$out/libflutter_engine.so"
  test -s "$src/out/$out/flutter_embedder.h"
  cmd_env "$variant"
}

cmd_env() {
  printf 'export VESHELL_LOCAL_ENGINE=%s\n' "$src/out/$(out_name "${1:-debug_unopt}")"
}

case "${1:-}" in
  sync)  shift; cmd_sync "$@" ;;
  build) shift; cmd_build "$@" ;;
  env)   shift; cmd_env "$@" ;;
  *) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
