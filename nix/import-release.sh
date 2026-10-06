#!/usr/bin/env bash
# Explicitly trust the repository's named branch/workflow before a root import.
# Usage: bash nix/import-release.sh COMMIT TAG package SOURCE_REF --trust-github-release
set -euo pipefail
export LC_ALL=C
export GH_HOST=github.com
commit=${1:?Expected the trusted full 40-hex source commit}
tag=${2:?Expected nix-engine-HASH release tag}
kind=${3:?Expected package}
ref=${4:?Expected refs/heads/ci/nix-source-release, refs/heads/main or a refs/tags/* ref}
[[ $# == 5 && $5 == --trust-github-release ]] || {
  echo 'Root import requires explicit --trust-github-release consent.' >&2; exit 1;
}
[[ $kind == package ]] || {
  echo 'This helper imports package releases only; engine packaging lives in flutter-engine-nix.' >&2; exit 1;
}
[[ $commit =~ ^[0-9a-f]{40}$ && $tag =~ ^nix-engine-([0-9a-z]{32})-source-([0-9a-f]{40})$ ]]
engine_hash=${BASH_REMATCH[1]}
package_commit=${BASH_REMATCH[2]}
[[ $package_commit == "$commit" ]]
[[ $ref == refs/heads/ci/nix-source-release || $ref == refs/heads/main || $ref == refs/tags/* ]]
repo=free-explorers/veshell
directory=$(mktemp -d)
trap 'rm -rf "$directory"' EXIT
gh release view "$tag" --repo "$repo" --json targetCommitish > "$directory/release.json"
jq -e --arg commit "$commit" '.targetCommitish == $commit' "$directory/release.json" >/dev/null
gh release download "$tag" --repo "$repo" --dir "$directory" --pattern "$kind-SHA256SUMS"
gh attestation verify "$directory/$kind-SHA256SUMS" --repo "$repo" \
  --cert-identity "https://github.com/$repo/.github/workflows/nix-package-release.yml@$ref" \
  --source-ref "$ref" --source-digest "$commit" --deny-self-hosted-runners
# Validate every manifest name before passing it to gh or checksum tooling.
names=()
while IFS= read -r line || [[ -n $line ]]; do
  [[ $line =~ ^[0-9a-f]{64}\ \ ($kind-metadata\.json|$kind-export\.part-[0-9]{4})$ ]]
  names+=("${BASH_REMATCH[1]}")
done < "$directory/$kind-SHA256SUMS"
(( ${#names[@]} >= 2 )) && [[ ${names[0]} == "$kind-metadata.json" ]]
for (( i=1; i<${#names[@]}; i++ )); do
  printf -v expected '%s-export.part-%04d' "$kind" "$((i-1))"
  [[ ${names[i]} == "$expected" ]]
done
for name in "${names[@]}"; do
  available=$(df --output=avail -B1 "$directory" | tr -dc '0-9')
  (( available >= (1900 + 2048) * 1024 * 1024 ))
  gh release download "$tag" --repo "$repo" --dir "$directory" --pattern "$name"
done
(
  cd "$directory"
  sha256sum --strict --check "$kind-SHA256SUMS"
)
parts_json=$(printf '%s\n' "${names[@]:1}" | jq -Rsc 'split("\n")[:-1]')
metadata="$directory/$kind-metadata.json"
jq -e --arg commit "$commit" --arg ref "$ref" --arg kind "$kind" \
  --arg hash "$engine_hash" --argjson parts "$parts_json" '
  .schema == 2 and .repository == "free-explorers/veshell" and
  .sourceCommit == $commit and .sourceRef == $ref and .kind == $kind and
  .system == "x86_64-linux" and .parts == $parts and
  .engineRepository == "free-explorers/flutter-engine-nix" and
  (.engineSourceRevision | test("^[0-9a-f]{40}$")) and
  (.engineRepositorySha256 | type == "string" and length > 0) and
  (.runtimeOutput | startswith("/nix/store/" + $hash + "-")) and
  (.nixpkgsRevision | test("^[0-9a-f]{40}$")) and
  (.roots | length == 3) and (.roots | unique | length == 3) and
  (.closure | length > 0) and (.requiredClosure | length > 0) and
  (all(.roots[], .closure[], .requiredClosure[], .runtimeOutput, .rawEngineOutput;
    test("^/nix/store/[0-9a-z]{32}-[^/[:space:]]+$"))) and
  (.closure as $closure | all(.roots[]; . as $root | $closure | index($root) != null)) and
  (.requiredClosure as $required | all(.rawEngineOutput, .runtimeOutput;
    . as $path | $required | index($path) != null)) and
  (.requiredClosure as $required | all(.closure[]; . as $path | $required | index($path) == null))
   ' "$metadata" >/dev/null
# Never obtain the helper or the expected engine pin from downloaded metadata.
# Run from a trusted Veshell checkout with matching nix/engine-repository.json.
pins=$(jq -ec 'select(.repository == "free-explorers/flutter-engine-nix" and
  (.revision | test("^[0-9a-f]{40}$")) and (.sha256 | type == "string" and length > 0))' nix/engine-repository.json)
if ! jq -e --argjson pins "$pins" '
  .engineRepository == $pins.repository and .engineSourceRevision == $pins.revision and
  .engineRepositorySha256 == $pins.sha256' "$metadata" >/dev/null; then
  echo 'Authenticated package engine pin differs from this trusted checkout. Use a trusted checkout matching the requested Veshell commit; do not adopt pins from release metadata.' >&2
  exit 1
fi
definitions=$(nix-instantiate --eval --strict --json --expr '
  let r = import ./nix/release.nix; in {
    source = toString r.engineSource; revision = r.engineSourceRevision;
    raw = r.rawEngine.outPath; runtime = r.runtime.outPath; nixpkgs = r.nixpkgsRevision;
  }')
engine_source=$(jq -er .source <<< "$definitions")
engine_commit=$(jq -er .revision <<< "$definitions")
[[ $engine_commit == "$(jq -r .revision <<< "$pins")" ]]
raw=${EXPECTED_RAW_ENGINE_OUTPUT:-$(jq -er .raw <<< "$definitions")}
runtime=${EXPECTED_RUNTIME_OUTPUT:-$(jq -er .runtime <<< "$definitions")}
[[ ${EXPECTED_ENGINE_OUTPUT:-$raw} == "$raw" ]]
if ! jq -e --arg raw "$raw" --arg runtime "$runtime" \
  --arg nixpkgs "${EXPECTED_NIXPKGS_REVISION:-$(jq -er .nixpkgs <<< "$definitions")}" \
  '.rawEngineOutput == $raw and .runtimeOutput == $runtime and .nixpkgsRevision == $nixpkgs' "$metadata" >/dev/null; then
  echo 'Authenticated package engine/runtime outputs or nixpkgs pin do not match the trusted release definitions (or explicit EXPECTED_* values).' >&2
  exit 1
fi
# Existing store paths alone do not prove provenance. Authenticate the separate
# dependency release every time, before any application root import.
EXPECTED_ENGINE_OUTPUT="$raw" EXPECTED_RAW_ENGINE_OUTPUT="$raw" EXPECTED_RUNTIME_OUTPUT="$runtime" \
  bash "$engine_source/import-release.sh" "$engine_commit" "nix-engine-$engine_hash" \
    engine refs/heads/main --trust-github-release
mapfile -t required < <(jq -r '.requiredClosure[]' "$metadata")
nix-store --check-validity "${required[@]}"
nix-store --query --requisites "$raw" "$runtime" | sort -u > "$directory/required.txt"
required_json=$(jq -Rsc 'split("\n")[:-1]' "$directory/required.txt")
jq -e --argjson required "$required_json" '.requiredClosure == $required' "$metadata" >/dev/null
# Assemble only the attested ordered list, never a wildcard. Decompress and check
# the complete stream before sudo so corrupt/truncated parts cannot start import.
part_paths=()
for name in "${names[@]:1}"; do part_paths+=("$directory/$name"); done
available=$(df --output=avail -B1 "$directory" | tr -dc '0-9')
(( available > 2 * 1024 * 1024 * 1024 ))
(
  # Bound decompression by current free disk minus the 2 GiB safety margin.
  ulimit -f "$(( (available - 2 * 1024 * 1024 * 1024) / 1024 ))"
  cat "${part_paths[@]}" | xz -d > "$directory/closure.export"
)
archive_bytes=$(stat --format=%s "$directory/closure.export")
available=$(df --output=avail -B1 /nix/store | tr -dc '0-9')
# Reserve enough room for the entire decoded closure, even in an empty store.
(( available >= archive_bytes + 2 * 1024 * 1024 * 1024 ))
echo "Importing verified $kind closure as root; trusting $repo at $commit ($ref)." >&2
nix-store --check-validity "${required[@]}"
# The caller intentionally opens the verified file; sudo only runs the importer.
# shellcheck disable=SC2024
sudo nix-store --import < "$directory/closure.export"
mapfile -t roots < <(jq -r '.roots[]' "$metadata")
nix-store --check-validity "${roots[@]}"
mapfile -t closure < <(jq -r '.closure[]' "$metadata")
nix-store --check-validity "${closure[@]}"
printf 'Verified roots:\n%s\n' "${roots[@]}"
