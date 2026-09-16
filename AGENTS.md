# Agent notes: toolchain and verification (bare minimum)

The code and `docs/specifications/` are the source of truth for design. These
notes record only tooling facts and traps. They are intentionally
version-free; every versionable fact is anchored in a project file.

## Toolchain

- The Flutter SDK is **project-managed**: the pin lives in the root
  `Cargo.toml` under `[package.metadata] flutter_version`, and
  `extra/build/flutter_sdk.rs` clones/checks-out `.flutter_sdk` to match it,
  comparing against `.flutter_sdk/version`. Do not hardcode versions anywhere
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
3. `cargo fmt` — format before committing.

## Diagnosing Dart-side problems directly

Run from `src/shell/`, using `.flutter_sdk/bin/dart`:

- `dart run build_runner build --delete-conflicting-outputs`
- If the incremental cache looks stale or generated files have grudges:
  `dart run build_runner clean` first, then rebuild.
- `flutter build linux --debug` reproduces the Dart compile errors on their
  own, without the full cargo gate.

## Where things live

- `docs/dependencies.md`: dependency versions and system packages.
- `docs/specifications/`: feature contracts (the milestones live there).
- `docs/agents/flutter-codegen-rules.md`: Dart codegen conventions and the
  platform-channel naming contract.
- `extra/build/shell.rs`: the shell build pipeline implementation.
