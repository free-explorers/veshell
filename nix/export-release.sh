#!/usr/bin/env bash
# Usage: bash nix/export-release.sh package NEW_DIRECTORY PACKAGE SDK SHELL
set -euo pipefail
export LC_ALL=C
kind=${1:?Expected package}
directory=${2:?Expected a new export directory}
shift 2
[[ $kind == package && $# == 3 ]]
[[ ${GITHUB_REPOSITORY:-} == free-explorers/veshell ]]
[[ ${GITHUB_SHA:-} =~ ^[0-9a-f]{40}$ ]]
[[ ${GITHUB_REF:-} == refs/heads/ci/nix-source-release || ${GITHUB_REF:-} == refs/heads/main ]]
[[ ${ENGINE_OUTPUT:-} =~ ^/nix/store/[0-9a-z]{32}-[^/]+$ ]]
[[ ${RAW_ENGINE_OUTPUT:-} =~ ^/nix/store/[0-9a-z]{32}-[^/]+$ ]]
[[ ${RUNTIME_OUTPUT:-} =~ ^/nix/store/[0-9a-z]{32}-[^/]+$ ]]
[[ $ENGINE_OUTPUT == "$RAW_ENGINE_OUTPUT" ]]
[[ ${NIXPKGS_REVISION:-} =~ ^[0-9a-f]{40}$ ]]
# Release definitions, not caller-supplied paths, determine all roots and pins.
definitions=$(nix-instantiate --eval --strict --json --expr '
  let r = import ./nix/release.nix; in {
    roots = [ r.package.outPath r.sdk.outPath r.shell.outPath ];
    raw = r.rawEngine.outPath; runtime = r.runtime.outPath;
    revision = r.engineSourceRevision; nixpkgs = r.nixpkgsRevision;
  }')
pins=$(jq -ec 'select(.repository == "free-explorers/flutter-engine-nix" and
  (.revision | test("^[0-9a-f]{40}$")) and (.sha256 | type == "string" and length > 0))' nix/engine-repository.json)
roots_json=$(printf '%s\n' "$@" | jq -Rsc 'split("\n")[:-1]')
jq -e --arg raw "$RAW_ENGINE_OUTPUT" --arg runtime "$RUNTIME_OUTPUT" \
  --arg nixpkgs "$NIXPKGS_REVISION" --argjson pins "$pins" --argjson roots "$roots_json" \
  '.raw == $raw and .runtime == $runtime and .revision == $pins.revision and
   .nixpkgs == $nixpkgs and .roots == $roots' <<< "$definitions" >/dev/null
[[ ! -e $directory ]]
mkdir -p "$directory"
directory=$(realpath "$directory")
roots=("$@")
for root in "${roots[@]}"; do
  [[ $root =~ ^/nix/store/[0-9a-z]{32}-[^/]+$ ]]
  nix-store --check-validity "$root"
done
if [[ ! -L ${roots[0]}/lib/veshell/libflutter_engine.so ]] ||
  [[ $(readlink -f "${roots[0]}/lib/veshell/libflutter_engine.so") != "$RUNTIME_OUTPUT/lib/libflutter_engine.so" ]]; then
  echo 'Package must symlink the standalone runtime engine, not copy engine bytes into its output.' >&2
  exit 1
fi
if [[ -e ${roots[0]}/lib/veshell/libflutter_linux_gtk.so || -e ${roots[2]}/lib/libflutter_linux_gtk.so ]]; then
  echo 'Application outputs still contain the unused GTK Flutter engine. Remove it from shell/package outputs before export; engine packaging belongs to flutter-engine-nix.' >&2
  exit 1
fi
nix-store --check-validity "$RAW_ENGINE_OUTPUT" "$RUNTIME_OUTPUT"
# No source-engine or runtime bytes belong in the application release.
nix-store --query --requisites "$RAW_ENGINE_OUTPUT" "$RUNTIME_OUTPUT" | sort -u > "$directory/required.txt"
nix-store --query --requisites "${roots[@]}" | sort -u > "$directory/application.txt"
comm -23 "$directory/application.txt" "$directory/required.txt" > "$directory/closure.txt"
mapfile -t closure < "$directory/closure.txt"
(( ${#closure[@]} > 0 ))
roots_json=$(printf '%s\n' "${roots[@]}" | jq -Rsc 'split("\n")[:-1]')
closure_json=$(jq -Rsc 'split("\n")[:-1]' "$directory/closure.txt")
required_json=$(jq -Rsc 'split("\n")[:-1]' "$directory/required.txt")
jq -en --argjson roots "$roots_json" --argjson closure "$closure_json" \
  '$closure as $paths | all($roots[]; . as $root | $paths | index($root) != null)' >/dev/null
rm "$directory/closure.txt" "$directory/required.txt" "$directory/application.txt"
available=$(df --output=avail -B1 "$directory" | tr -dc '0-9')
(( available >= 2 * 1024 * 1024 * 1024 ))
# Each part stays below GitHub's 2 GiB asset limit; compression uses <= 4 CPUs.
export EXPORT_PREFIX="$directory/$kind-export.part-"
# The child shell expands its own arguments and exported prefix.
# shellcheck disable=SC2016
setsid bash -euo pipefail -c '
  nix-store --export "$@" | xz -T4 -1 |
    split --bytes=1900M --numeric-suffixes=0 --suffix-length=4 - "$EXPORT_PREFIX"
' _ "${closure[@]}" &
pid=$!
trap 'kill -TERM -- -"$pid" 2>/dev/null || true' EXIT INT TERM
while kill -0 "$pid" 2>/dev/null; do
  available=$(df --output=avail -B1 "$directory" | tr -dc '0-9')
  if (( available < 2 * 1024 * 1024 * 1024 )); then
    echo 'Stopping closure export: less than 2 GiB remains.' >&2
    exit 1
  fi
  sleep 5
done
wait "$pid"
trap - EXIT INT TERM
parts=()
shopt -s nullglob
for part in "$directory/$kind-export.part-"*; do parts+=("$(basename "$part")"); done
(( ${#parts[@]} > 0 ))
parts_json=$(printf '%s\n' "${parts[@]}" | jq -Rsc 'split("\n")[:-1]')
jq -n --arg kind "$kind" --arg sourceCommit "$GITHUB_SHA" --arg sourceRef "$GITHUB_REF" \
  --arg rawEngineOutput "$RAW_ENGINE_OUTPUT" --arg runtimeOutput "$RUNTIME_OUTPUT" \
  --argjson engineRepositoryPins "$pins" --argjson requiredClosure "$required_json" \
  --arg nixpkgsRevision "$NIXPKGS_REVISION" --argjson roots "$roots_json" \
  --argjson closure "$closure_json" --argjson parts "$parts_json" \
  --slurpfile sdkPins nix/flutter-sdk.json \
  '{schema:2,kind:$kind,sourceCommit:$sourceCommit,sourceRef:$sourceRef,
    repository:"free-explorers/veshell",system:"x86_64-linux",
    engineRepository:$engineRepositoryPins.repository,
    engineSourceRevision:$engineRepositoryPins.revision,
    engineRepositorySha256:$engineRepositoryPins.sha256,
    rawEngineOutput:$rawEngineOutput,runtimeOutput:$runtimeOutput,requiredClosure:$requiredClosure,
    nixpkgsRevision:$nixpkgsRevision,sdkPins:$sdkPins[0],
    roots:$roots,closure:$closure,parts:$parts}' > "$directory/$kind-metadata.json"
(
  cd "$directory"
  sha256sum "$kind-metadata.json" "${parts[@]}" > "$kind-SHA256SUMS"
)
