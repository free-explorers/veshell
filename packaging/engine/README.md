# Building the Flutter engine for Veshell

Veshell links a specific Flutter engine revision and ships its embedder runtime.
Those binaries are currently consumed from
[meta-flutter/flutter-engine](https://github.com/meta-flutter/flutter-engine).
This directory builds them **ourselves** so the dependency can be dropped.

`build-engine.sh` reproduces the Linux x86_64 build from meta-flutter: it syncs
`flutter/engine` at the pinned revision with `gclient`, installs the Debian
bullseye sysroot, builds with `gn` + `ninja`, and packages the SDK. The sysroot
is what makes the result portable to Debian and Fedora — the Nix engine build in
`flutter-engine-nix` patches its outputs to the Nix loader and cannot be dropped
into the distro recipes.

## Output

```
linux-engine-sdk-release-x86_64-<revision>.tar.gz
linux-engine-sdk-release-x86_64-<revision>.tar.gz.sha256
```

The tarball's `flutter/engine/src/out/<out>/engine-sdk/{include,lib}` holds
`flutter_embedder.h` and `libflutter_engine.so`, exactly what
`packaging/scripts/build-veshell.sh` and the project's dev build read. That is
the same artifact contract (names, layout) as the meta-flutter releases, so
switching is only a matter of changing the owner/repo in the download URL.

## Running it

Locally (x86_64-linux, needs `git`, `python3`, `ninja`, `gn`, network, and a lot
of disk and time):

```sh
packaging/engine/build-engine.sh release "$(cat .flutter_sdk/bin/internal/engine.version)" dist
```

In CI, dispatch the `Engine Release` workflow with the engine revision. It
publishes a GitHub release tagged
`linux-engine-sdk-<mode>-x86_64-<revision>` and prints the exact `release.json`
update.

## Switching Veshell to our engine

1. Build and publish the `release` engine for the pinned revision (and `debug`
   if you want keyless dev builds).
2. Point the manifest at it and re-render:

   ```jsonc
   "flutter": {
     "engine": {
       "url": "https://github.com/free-explorers/veshell/releases/download/linux-engine-sdk-release-x86_64-<revision>/linux-engine-sdk-release-x86_64-<revision>.tar.gz",
       "sha256": "<from the .sha256 asset>"
     }
   }
   ```

   ```sh
   packaging/scripts/render-recipes.py
   packaging/scripts/render-recipes.py --check
   ```

3. For dev builds, set `VESHELL_ENGINE_REPO=free-explorers/veshell` (see
   `extra/build/flutter_engine_lib.rs`); it defaults to `meta-flutter/flutter-engine`.

## Provenance

`build-engine.sh` and `patches/0001-clang-toolchain.patch` are adapted from
[meta-flutter/flutter-engine](https://github.com/meta-flutter/flutter-engine),
licensed Apache-2.0. The patch is vendored verbatim (author: Joel Winarske).
