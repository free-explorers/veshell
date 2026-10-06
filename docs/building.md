# Building and packaging

Veshell has a development bootstrap path and an external-input packaging path.
Both use the Flutter version in `Cargo.toml`; do not substitute an arbitrary
Flutter or Dart executable from `PATH`. See [dependencies](dependencies.md) for
native libraries and [NixOS packaging](nixos.md) for Nix-specific instructions.

## Development

```sh
cargo run
```

Cargo prepares the project-managed `.flutter_sdk`, resolves Dart dependencies,
runs code generation, builds the shell, obtains the matching engine, and builds
the Rust compositor. This path may access the network and writes build outputs
inside the checkout. It is not a hermetic distro build.

For direct code generation, after resolving dependencies:

```sh
cd src/shell
../../.flutter_sdk/bin/flutter pub get
../../.flutter_sdk/bin/dart run build_runner build
```

With the pinned generator set, codegen needs no source patching. Do not run
pub-get/codegen concurrently in the same shell directory. After forcibly
terminating code generation, rerun `flutter pub get` before the next
invocation.

Rust optimization profiles and Flutter runtime modes are distinct. Standard
`debug`, `profile`, and `release` output directories select the corresponding
Flutter mode. For a custom Cargo profile, set `VESHELL_FLUTTER_MODE` explicitly
to one of those modes. Cargo's `PROFILE` classification is not used to identify
the custom `profile` directory. Inference finds the profile above Cargo's
`build/` directory and supports both `build/<package>-<hash>/out` and
`build/<package>/<hash>/out` layouts, rather than assuming a fixed depth.

## Offline packaging

Fetch/vendor dependencies and build the shell separately before compiling Rust.
The prepared shell must use the selected engine's matching frontend, platform
kernel, and AOT compiler; equal version strings alone do not establish snapshot
compatibility. Packaging controls that pairing.

When building the shell, use
`--dart-define=VESHELL_POLKIT_HELPER_PATH=/final/path/to/polkit-agent-helper-1`
for distributions with a different fallback helper location. The development
Cargo pipeline accepts the same setting as `VESHELL_POLKIT_HELPER_PATH`.
It must be selected before AOT compilation, not during staging.

Supply both external inputs:

| Variable | Required layout |
| --- | --- |
| `VESHELL_PREBUILT_SHELL` | `lib/libapp.so`, `data/icudtl.dat`, `data/flutter_assets/` |
| `VESHELL_ENGINE_DIR` | `flutter_embedder.h`, `<mode>/libflutter_engine.so` |
| `VESHELL_FLUTTER_MODE` | `debug`, `profile`, or `release`; normally `release` |

Debug bundles need `data/flutter_assets/kernel_blob.bin` instead of `libapp.so`.
The build script validates these files and rejects a shell or engine supplied
alone. With both supplied it does not clone an SDK, run pub/codegen/Flutter, or
download an engine. Cargo dependencies must still be available offline.
Automatic SDK/engine bootstrap is native-only; cross builds require prepared
target artifacts and the usual Rust/native toolchain configuration.

Compile the final runtime paths, never a staging prefix:

```sh
VESHELL_PREBUILT_SHELL=/build/shell \
VESHELL_ENGINE_DIR=/build/engine \
VESHELL_FLUTTER_MODE=release \
VESHELL_LIB_DIR=/usr/lib/veshell \
VESHELL_DATA_DIR=/usr/share/veshell/data \
VESHELL_DEFAULT_CONFIG_DIR=/usr/share/veshell/settings/default \
cargo build --locked --offline --release
```

`VESHELL_LIB_DIR` and `VESHELL_DATA_DIR` must be supplied together and be absolute.
Without installed-path overrides, source/external-bundle builds use their build
outputs and project settings. The default-settings path can also be overridden
at runtime. Engine header, library, architecture, and runtime mode must match;
the file checks are not a complete ABI compatibility test.

## Staged installation

`make install` only copies prepared artifacts. It does not compile, fetch
dependencies, start services, or invoke sudo. `make package` is an alias for the
same installer.

```sh
make build PREFIX=/usr PROFILE=release
make install PREFIX=/usr DESTDIR=/build/package-root
```

`make build` sets the final library, data, default-settings, and Flutter-mode
variables. For external inputs, export them first; use `CARGO_NET_OFFLINE=true`
to prohibit Cargo network access. Custom Rust profiles require
`FLUTTER_MODE=debug|profile|release` on Make invocations.

`PREFIX` and directory overrides describe the final installation.
`DESTDIR` is used only while copying. The installer includes native shell/plugin
libraries, the embedder engine, AOT code or debug kernel, assets, settings,
session scripts, portal descriptors, and generated systemd user units.
The unused Flutter GTK runner library is excluded.

Overrides include `BINDIR`, `LIBDIR` (the private Veshell library directory),
`SHAREDIR`, `SESSIONDIR`, `PORTALDIR`, and `SYSTEMD_USER_DIR`, as well as `BIN`,
`ENGINE_LIB`, `APP_LIB`, `SHELL_LIB_DIR`, and `DATA_DIR`. `CARGO_TARGET_DIR` and
`TARGET` control Rust output discovery. Unknown architectures need explicit
supported target/artifact configuration rather than silently selecting arm64.
`INSTALL_ENGINE=0` leaves an externally managed engine untouched; the packager
must provide its runtime dependency and loader search path.

For the local build-and-install shortcut:

```sh
make install-local
```

That explicitly builds and uses sudo for installation under `/usr/local`.
Use the same final directory overrides for `sudo make uninstall`.

## Debian and RPM payloads

Build with final `/usr` paths, then stage a fresh payload:

```sh
make build PREFIX=/usr
make stage
cargo deb --no-build
cargo generate-rpm
```

`make stage` uses `build/package-root` by default and refuses a nonempty staging
directory. Both Cargo packaging metadata tables consume its complete `/usr`
payload; package versions come from Cargo's package version. `make deb` and
`make rpm` combine fresh staging with archive generation, but do not build.
Custom installation layouts need corresponding distro packaging metadata.

These are payload-generation helpers, not fully validated distro packages.
Packagers must declare native runtime dependencies and required services,
configure polkit/helper paths, and follow their distro's installation policy.
Do not use Nix-linked binaries as portable Debian/RPM release artifacts.

## Distribution packaging

Ready-to-use recipes for Arch/Manjaro, Fedora and Debian live in
[`packaging/`](../packaging/README.md). They build the Dart shell and the Rust
compositor from source and consume only pinned, checksummed upstream Flutter
inputs; the Rust build and `pub get` run offline against vendored trees. The
same recipes explain why Flutter keeps these packages out of the Debian and
Fedora main repositories today.

The embedding engine is currently a pinned upstream artifact. It is built from
source in the dedicated `free-explorers/flutter-engine` repository; its releases
are not held in this repository.

## Checks

```sh
bash extra/tests/packaging_install.sh
rustc --edition 2021 --test extra/build/config.rs -o /tmp/veshell-build-config-tests
/tmp/veshell-build-config-tests
```

The staging and codegen fixtures do not download an engine or start a desktop.
Set `TEST_ARCHIVES=1` for staging tests to also inspect a Debian archive when
`cargo-deb`, a C compiler, and Debian archive tools are available.
