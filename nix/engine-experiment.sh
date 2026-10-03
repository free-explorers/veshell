#!/usr/bin/env bash
set -euo pipefail

started=$(date +%s)
summary=${GITHUB_STEP_SUMMARY:-/dev/stdout}

# A separate process group lets the disk guard stop the entire local builder.
setsid /usr/bin/time --verbose timeout --signal=INT --kill-after=60s 300m \
  nix-build nix/engine-experiment.nix --no-out-link --max-jobs 1 --cores 4 &
build_pid=$!
trap 'kill -INT -- -"$build_pid" 2>/dev/null || true' INT TERM EXIT

disk_limit=false
while kill -0 "$build_pid" 2>/dev/null; do
  date -u
  free -h
  df -h / /nix/store
  available=$(df --output=avail -B1 /nix/store | tr -dc '0-9')
  if (( available < 2 * 1024 * 1024 * 1024 )); then
    echo "Stopping engine build: less than 2 GiB disk space remains."
    disk_limit=true
    kill -TERM -- -"$build_pid" 2>/dev/null || true
    break
  fi
  sleep 60
done

result=0
wait "$build_pid" || result=$?
trap - INT TERM EXIT
elapsed=$(( $(date +%s) - started ))
{
  echo '## Source Engine Experiment'
  echo "- Build exit status: $result"
  echo "- Elapsed seconds: $elapsed"
  echo "- Disk guard triggered: $disk_limit"
  echo '- Runner: standard ubuntu-24.04; one build, four compilation jobs.'
  echo '- No cache service, release uploads, or artifact uploads used.'
} >> "$summary"
if "$disk_limit"; then
  exit 1
fi
if (( result != 0 )); then
  exit "$result"
fi

engine=$(nix-build nix/engine-experiment.nix --no-out-link --max-jobs 1 --cores 4)
output="$engine/out/host_release"
trap 'result=$?; echo "::error::Engine verification failed at line $LINENO: $BASH_COMMAND"; exit "$result"' ERR
for artifact in \
  libflutter_engine.so flutter_embedder.h gen_snapshot dart-sdk/bin/dart \
  dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot \
  flutter_patched_sdk/platform_strong.dill \
  flutter_patched_sdk_product/platform_strong.dill icudtl.dat \
  libflutter_linux_gtk.so gen/const_finder.dart.snapshot; do
  echo "Checking artifact: $output/$artifact"
  if [[ ! -s "$output/$artifact" ]]; then
    echo "::error::Missing or empty engine artifact: $output/$artifact"
    ls -la "$output"
    exit 1
  fi
done
for executable in gen_snapshot dart-sdk/bin/dart; do
  echo "Checking executable: $output/$executable"
  test -x "$output/$executable"
done
echo "Checking Linux headers: $output/flutter_linux"
test -d "$output/flutter_linux"
"$output/gen_snapshot" --version
"$output/dart-sdk/bin/dart" --version

for library in libflutter_engine.so libflutter_linux_gtk.so; do
  dependencies=$(ldd "$output/$library")
  echo "$dependencies"
  if [[ "$dependencies" == *'not found'* ]]; then
    echo "Unresolved dependencies in $library."
    exit 1
  fi
done

{
  echo "- Verified engine output: \`$engine\`"
  echo '- Engine, local AOT tooling, frontend, product kernel, ICU, and Linux embedding artifacts exist.'
  echo '- Shared-library dependencies resolve; Veshell AOT startup is not tested by this experiment.'
} >> "$summary"
