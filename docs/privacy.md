# Privacy and telemetry

Veshell ships no analytics and does not phone home. The Flutter and Dart *build
tools* do report usage telemetry to Google by default, so this page separates
what runs on a user's machine from what runs on a developer's or packager's
machine, and records how the project build suppresses that telemetry.

## Runtime

The installed shell (`src/`) contains no analytics or telemetry code and makes
no requests to Google. The Flutter engine and framework do not report usage at
runtime, and no dependency in `src/shell/pubspec.yaml` is an analytics SDK.

The shell's own source contains no telemetry; the only outbound HTTP request in
it is user-driven: album art advertised by a media player over MPRIS is fetched
when it is an `http(s)` URL. The remaining integrations (D-Bus, NetworkManager,
BlueZ, PulseAudio, UPower, polkit, portals) are local.

## Build tooling

The Flutter and Dart CLI tools include `unified_analytics`, which reports usage
and diagnostics to Google Analytics. This affects anyone building Veshell from
source, not the people running a released package.

### What is sent

| Item | Value (at the time of writing) |
| --- | --- |
| Endpoint | `https://www.google-analytics.com/mp/collect` |
| Measurement ID | `G-04BXPVBCWJ` |
| Default state | enabled (`reporting=1`) |
| First run | nothing is sent; a consent notice is shown |
| Configuration | `$HOME/.dart-tool/dart-flutter-telemetry.config` |
| Data | tool and version, host OS/version, locale, session, a random client id |
| Policy | <https://policies.google.com/privacy> |

This behaviour comes from the pinned SDK (`unified_analytics`), not from
Veshell. See `nix/flutter-tools-lock.json` for the locked tooling set.

### How the project build suppresses it

- The automatic Cargo pipeline (`extra/build/shell.rs`) sets
  `FLUTTER_SUPPRESS_ANALYTICS=true` on every `flutter` invocation and passes
  `--suppress-analytics` to `dart run build_runner`. The suppression does not
  depend on the developer's global machine state.
- The manual commands in [building](building.md) use the same flags.
- The Nix build (`nix/shell.nix`) runs Flutter/Dart inside a network-isolated
  sandbox, and nixpkgs' `buildFlutterApplication` runs
  `flutter config --no-analytics` under a temporary `HOME`. No telemetry can be
  sent, and the engine is built from source.
- CI runners are detected as bots, which disables Flutter tool analytics.

### Opting out globally

Dart and Flutter share one telemetry configuration. To opt out for every
project on a machine, run either tool's persistent command once:

```sh
flutter --disable-analytics
dart --disable-analytics
```

`dart --suppress-analytics <command>` and `FLUTTER_SUPPRESS_ANALYTICS=true`
disable reporting for a single invocation without changing the configuration.
The state can be confirmed in `$HOME/.dart-tool/dart-flutter-telemetry.config`
(`reporting=0` means disabled).

## Artifact provenance

Analytics and artifact downloads are different concerns. The development
bootstrap downloads pre-built Dart and Flutter artifacts; these are ordinary
downloads, not telemetry.

| Artifact | Source | Integrity |
| --- | --- | --- |
| Flutter SDK | `github.com/flutter/flutter.git`, checked out by tag | pinned tag, not a commit |
| Dart SDK | `storage.googleapis.com/flutter_infra_release/...` | trusted over TLS |
| Linux engine artifacts | `storage.googleapis.com/flutter_infra_release/...` | trusted over TLS |
| Embedder `libflutter_engine.so` | a GitHub release (`meta-flutter/flutter-engine` by default, or `VESHELL_ENGINE_REPO`) | SHA-256 fetched from the same release |
| Dart packages | `pub.dev` and `github.com/free-explorers/*` | lockfile revisions |

The Nix path is stronger: `nix/flutter-sdk.json` pins SHA-256 hashes for the
SDK, Dart SDK and artifacts, and the embedder engine is built from source in
[flutter-engine-nix](https://github.com/free-explorers/flutter-engine-nix).
See [NixOS packaging](nixos.md) for the attested-closure workflow.

## Verifying

To audit a build, watch the tool invocations in `extra/build/shell.rs` and
confirm the suppression flags are present, or inspect the telemetry
configuration before and after a build:

```sh
cat "$HOME/.dart-tool/dart-flutter-telemetry.config"
```

A build that uses the automatic pipeline must not change `reporting` and must
not create `$HOME/.dart-tool/dart-flutter-telemetry.log` entries.
