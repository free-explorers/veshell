# The Flutter engine

Veshell links a pinned Flutter engine revision and ships its embedder runtime.

**Engine releases do not live in the Veshell repository.** They are built and
published by the dedicated engine repository:

> `free-explorers/flutter-engine`

That repository is a fork of
[meta-flutter/flutter-engine](https://github.com/meta-flutter/flutter-engine)
with an added GitHub-hosted build (`build-engine.sh` and
`.github/workflows/engine-release.yml`) that produces a portable Linux x86_64
SDK. It uses the Debian bullseye sysroot so the result runs on Debian and
Fedora — unlike the Nix engine build in `flutter-engine-nix`, whose outputs are
patched to the Nix loader.

```
linux-engine-sdk-release-x86_64-<revision>.tar.gz
linux-engine-sdk-release-x86_64-<revision>.tar.gz.sha256
```

The tarball's `flutter/engine/src/out/<out>/engine-sdk/{include,lib}` holds
`flutter_embedder.h` and `libflutter_engine.so`, exactly what
`packaging/scripts/build-veshell.sh` and the project's dev build read. It is the
same artifact contract (names, layout) as the meta-flutter releases, so
switching is only a matter of changing the owner/repo in the download URL.

## Switching Veshell to our engine

1. In `free-explorers/flutter-engine`, dispatch **Engine Release** with the
   pinned engine revision (mode `release`; run `debug` too for keyless dev
   builds). It publishes `linux-engine-sdk-<mode>-x86_64-<rev>`.
2. Point `packaging/release.json` at it and re-render:

   ```jsonc
   "flutter": {
     "engine": {
       "url": "https://github.com/free-explorers/flutter-engine/releases/download/linux-engine-sdk-release-x86_64-<revision>/linux-engine-sdk-release-x86_64-<revision>.tar.gz",
       "sha256": "<from the .sha256 asset>"
     }
   }
   ```

   ```sh
   packaging/scripts/render-recipes.py
   packaging/scripts/render-recipes.py --check
   ```

3. For dev builds, set `VESHELL_ENGINE_REPO=free-explorers/flutter-engine` (see
   `extra/build/flutter_engine_lib.rs`; it defaults to
   `meta-flutter/flutter-engine`).
