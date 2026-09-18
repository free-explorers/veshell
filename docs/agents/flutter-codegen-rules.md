# Flutter/Dart codegen rules and platform-channel contract

Conventions the generator toolchain relies on. Violating them produces the
traps listed at the bottom; the compositor side reads these files, so drift
breaks the build, not just style.

## File and part conventions

- Freezed models: `lib/<module>/model/<name>/<name>.serializable.dart` with
  `part '<name>.serializable.freezed.dart';` and
  `part '<name>.serializable.g.dart';`.
- Riverpod providers: `lib/<module>/provider/<name>.dart` with
  `part '<name>.g.dart';` and the `@riverpod` annotation.
- Widgets: `lib/<module>/widget/`.

## Freezed rules

- Every `@freezed` class must declare its own `fromJson` factory; otherwise
  `json_serializable` fails with "Could not resolve annotation for …".
- Classes consumed by the platform channel implement
  `PlatformMessage` (from `platform_manager.dart`), exactly like every other
  generated model in the tree.
- The freezed part file must exist and be analyzable before `flutter build`
  runs: a missing part file surfaces as "Type `_$X` not found" together with
  "no `part of` declaration", and build_runner will not emit it again while
  the source does not parse. Delete the stale generated files and re-run
  `dart run build_runner build --delete-conflicting-outputs`.

## Platform-channel naming contract

- Compositor-to-shell events: Rust calls
  `platform_method_channel.invoke_method("<name>", …)` and the Dart
  `PlatformEvent` union factory whose **snake_case of the factory name**
  equals `<name>` receives it (freezed `unionValueCase: snake`). Renaming
  either side requires the matching change on the other; the association is
  by string, checked nowhere statically.
- Shell-to-compositor requests: a `PlatformRequest` subclass with
  `method: '<name>'`; the Rust side dispatches the same string in
  `platform_channel_callbacks/mod.rs` and implements the handler in its own
  `platform_channel_callbacks/<name>.rs`.
- Payloads are plain JSON; the Rust side deserializes with
  `#[serde(rename_all = "camelCase")]` to match Dart's default field names.

## Platform event plumbing checklist

1. Rust: `invoke_method` calls the exact snake_case name.
2. Dart: add the freezed model under `model/<name>/`, import it, and register
   the union factory in
   `lib/platform/model/event/platform_event.serializable.dart`.
3. Rust: implement the handler under `platform_channel_callbacks/` and
   register it in that directory's `mod.rs`.

## Quick diagnosis

- "Could not resolve annotation for `sealed class X`" → the freezed part file
  is missing or the mixin factory was not regenerated; rebuild codegen.
- "Type `_$X` not found" at `flutter build` → same cause.
- Pub-get failures naming an SDK constraint mean a non-pinned `dart`/`flutter`
  was used; see `AGENTS.md`.
