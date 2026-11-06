# Agent notes: toolchain and verification (bare minimum)

The code and `docs/specifications/` are the source of truth for design. These
notes record only tooling facts and traps. They are intentionally
version-free; every versionable fact is anchored in a project file.

## Toolchain

- The Flutter SDK is **project-managed**: the pin lives in the root
  `Cargo.toml` under `[package.metadata] flutter_version`, and
  `extra/build/flutter_sdk.rs` clones/checks-out `.flutter_sdk` to match it,
  verifying the checkout's exact git tag. Do not hardcode versions anywhere
  else, and go through these project files when the pin needs to move.
- The shell build pipeline is `extra/build/shell.rs`: it runs
  `flutter pub get`, `dart run build_runner build`, and
  `flutter build linux --debug/--profile/--release` from `src/shell/`, always
  with the SDK binaries from `.flutter_sdk/bin`. Any
  `flutter`/`dart` found on the generic `PATH` is not guaranteed to satisfy
  the shell's dependency constraints and must not be used for the shell.
- `cargo check` (repo root) is a **single-gate** verification: the build
  script chains pub-get + build_runner + the Flutter build, and fails loudly
  (panic) if any Dart-side step fails. Start here after Rust or Dart changes.

## Verification loop

1. `cargo check` — covers Rust compilation and the whole Dart side (see
   above).
2. `cargo test` — the test suites include the portal session-bus harness.
3. `cargo fmt` — format Rust before committing.
4. `dart format` — from `src/shell/`, format Dart before committing:
   `../../.flutter_sdk/bin/dart format lib test`. The **pinned** SDK's
   formatter defines the style, and CI enforces it
   (`--set-exit-if-changed`); a `dart` from the generic `PATH` may format
   differently, so never use one for the shell.

## Tests and user directories

Tests must never write to the user's directories (videos, config, data): give
the code under test a temporary directory instead. The recording tests used to
publish into `~/Videos`, leaving hundreds of header-only files there across
`cargo test` runs.

## Diagnosing Dart-side problems directly

Run from `src/shell/`, using `../../.flutter_sdk/bin/dart` (the SDK lives at
`.flutter_sdk/` in the repo root):

- `dart run build_runner build`
- If the incremental cache looks stale or generated files have grudges:
  `dart run build_runner clean` first, then rebuild.
- `flutter build linux --debug` reproduces the Dart compile errors on their
  own, without the full cargo gate.

## Dart tests

The root `cargo test` gate does not run Flutter tests. Run them with the
project SDK from `src/shell/`:

- `../../.flutter_sdk/bin/flutter test` (all tests), or
- `../../.flutter_sdk/bin/flutter test test/<file>_test.dart` (one file).

## Seeing the running shell: `veshell-probe`

`extra/probe/veshell-probe` (also `veshell-probe serve`, JSON-RPC tools on
stdio) sees, measures and drives a running **debug**
build (`cargo run`, or the VS Code "Run Veshell as Window" launch), found on its
VM service (ports 12345+). See `docs/specifications/veshell_probe.md`.

- `find` gives a widget's global rect, the part ancestor clips leave in view,
  and its opacity; `screenshot` captures what was actually painted; `tap`,
  `key`, `type` drive it; `state` snapshots screens, workspaces and windows.
- `start` runs an isolated instance in a headless display (its own config,
  data and user directories, the applications of `extra/probe/fixtures/`),
  used by default until `stop`; prefer it to probing the developer's own
  instance. Input goes through the compositor as a device's would.
- `scenario FILE` replays a check from `extra/probe/scenarios/` and compares
  its screenshots with references; turn a reproduced bug into a scenario.
- `animate` freezes the clock, plays an action and steps through exact,
  evenly spaced instants: a contact sheet, and the tracked widgets' geometry
  on each frame. `find` says whether a widget is `painted`, not only where
  it is laid out.
- `verify` is the gate below in one call, comparing `flutter test` with
  `extra/probe/known_failures.txt` (update that list when a known failure is
  fixed, never to hide a new one).

For a visual bug: reproduce it with `find`/`animate` first, and check that the
probe shows the fault before fixing it; after the fix, run the same probe
again, then `verify`. The instance must be rebuilt and restarted to pick up
Dart changes.

## Where things live

- `docs/dependencies.md`: dependency versions and system packages.
- `docs/specifications/`: feature contracts (the milestones live there).
- `docs/agents/flutter-codegen-rules.md`: Dart codegen conventions, comparison
  keys and the platform-channel naming contract. Never use geometry
  `.toString()` values as effect/cache keys; see that file for the release
  rounding trap.
- `extra/build/shell.rs`: the shell build pipeline implementation.
