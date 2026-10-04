# NixOS packaging

The package now selects a source-built Flutter engine on native x86_64 NixOS.
The historical source-engine experiment passed on GitHub's free hosted runner
for its previous target set. The new standalone `flutter-engine-nix` release
build is running, not yet verified as passed; the integrated shell/compositor
build is also awaiting verification.
Earlier full-package verification used the former prebuilt engine input. This
is local packaging support, not an official nixpkgs package. A complete
graphical login session has not yet been verified, and the running VM's desktop
configuration has not been changed.

## Engine And Distribution Decision

Decision recorded on 2026-10-03: the canonical Nix package will build Flutter's
engine from pinned upstream sources, rather than depend on meta-flutter's
precompiled engine archives. Veshell implements the embedder in Rust; Flutter's
engine is a separate runtime library. Official prebuilt SDK/bootstrap tools
are not excluded by this decision.

The source engine and its AOT compiler must be built together. Compile the
shell with that local engine's Dart/frontend and `gen_snapshot` artifacts, then
install the runtime library from the same derivation. Matching version strings
alone is not sufficient to establish snapshot compatibility.

Keep the SDK, engine, shell bundle, and compositor as separate derivations with
narrow source inputs. Veshell-only updates must not invalidate the engine build;
documentation changes should not invalidate application builds. Engine inputs
include its source revision, patches, dependencies, and toolchain.

For fast installation without a hosting budget, build these derivations in
project CI and publish their Nix runtime closures through GitHub Releases.
Verify GitHub's keyless provenance attestations before explicitly trusting a
root import. This is an export/import mechanism, not an automatic Nix binary
cache. Pin CI's nixpkgs revision and build each supported architecture. Start
with x86_64 Linux and add aarch64 once verified. A conventional signed binary
cache can be added later if free or donated hosting becomes available.

The cache distributes outputs of the source-build derivations; do not replace
the source build with a hardcoded download of a project-hosted `.so`. When a
matching cached output is unavailable, Nix must retain the source-build path.
After nixpkgs inclusion, use the official NixOS binary cache where builds are
available; the project cache serves development and releases not yet cached
there. Cache availability is not guaranteed for every revision or platform.

Engine packaging now lives in `free-explorers/flutter-engine-nix`, independently
of Veshell. `nix/engine-repository.json` pins its repository, full commit, and
`fetchTarball` hash. The pinned engine source supplies the build, runtime, AOT
checks, and engine release import/export helpers. Veshell provides an adapter
for its build layout, but does not publish the production engine itself.
Source-engine ELF interpreters are patched for NixOS before compiler launch
checks. Integrated builds, release export/import, and graphical runtime
verification still require a successful hosted integration run.

### Hosted Runner Experiment

The historical `Nix Engine Experiment` built only the source release engine,
independently of the then-verified meta-flutter-based package. Its entry point was
`nix/engine-experiment.nix`, with a hash-pinned nixpkgs revision. Those historical
results do not establish success of the standalone repository's new target set.

The experiment uses a free standard `ubuntu-24.04` runner, read-only repository
permissions, one Nix build, and four compilation jobs. It reclaims disposable
runner tooling, requires 30 GiB free before installation, and stops if free
space falls below 2 GiB during the build. Compilation has a 300-minute limit;
the whole job has a 330-minute limit. Resource samples and results remain in
Actions logs and the job summary. There are no paid runners, external cache
credentials, release uploads, or artifact uploads.

Success verifies engine and local compiler artifacts plus linked dependencies,
not Veshell frame presentation. Rebuild and test the shell against that engine
before migrating the default package or publishing cached release outputs.

The first hosted run (`37130708096`) completed all 8,232 engine build actions
and returned a successful Nix output in 2 hours 1 minute 39 seconds. The job
then failed a silent artifact check. The failing command was not logged; an
identified layout mismatch is that GN emits the release kernel under
`flutter_patched_sdk`, while verification expected `flutter_patched_sdk_product`.
The experiment supplied that product-path alias for Flutter's local
release lookup, and artifact checks report missing paths explicitly. The first
run also exposed the need to build the local `const_finder` tooling target.
The second run (`37143412684`) passed compilation and all corrected artifact
and shared-library checks in about 1 hour 53 minutes. It did not export binaries.
The subsequent NixOS ELF interpreter fix and standalone target changes require
a new engine output. The approved standalone build at engine repository commit
`7b4626beb035f6c8200366c32a4fe7e603904f27` compiled successfully, but its
post-build check used Ubuntu's `ldd` and failed against the newer Nix glibc.
The retry at `c61d2b5f85a6f1ef84ff890982496a4aca11d4e0` uses Nix's loader,
adds the runtime's fontconfig dependency, and excludes the unused GLFW targets.
It is running; no complete release success is claimed here.

That runner reported a 145 GiB root filesystem, with about 108 GiB available
after cleanup and a lowest sampled availability of 90 GiB during the build.
It reported 15 GiB RAM, with at least 11 GiB available in the minute-spaced
samples. These are observations from one runner, not guaranteed capacities or
exact compiler memory peaks. Neither disk nor memory guards caused the failure.

## Release Exports

`Nix Source Release` runs on a standard free `ubuntu-24.04` runner, by manual
dispatch only. It has no push or pull-request trigger. Dispatch on the explicitly
trusted `ci/nix-source-release` branch or `main` is available
once GitHub registers the workflow on the default branch. Authorized writers
to those branches are part of the trust boundary.

The workflow evaluates the pinned standalone engine outputs without building
them. The required engine tag is `nix-engine-RUNTIMEHASH`, where `RUNTIMEHASH`
comes from the standalone `runtime.outPath`, not Veshell's adapter. It requires
that tag in `free-explorers/flutter-engine-nix` to target the exact pinned engine
commit, then calls that pinned source's `import-release.sh` with the expected raw
engine and runtime paths. Engine provenance is verified against that repository's
own `release.yml` workflow on `refs/heads/main`, independently of Veshell's
attestation. If the release is missing, partial, or untrusted, Veshell fails;
there is no engine-build fallback in this release workflow.

Only after engine import does Veshell build the package, SDK, shell, and headless
AOT loader check. It exports exactly three roots: package, SDK, and shell. The
full raw-engine and runtime closures are subtracted from application exports
and listed as `requiredClosure` in schema-2 package metadata, alongside the
required engine repository, commit, source hash, and engine/runtime output paths.
The release contract requires the package to reference the runtime engine by
store symlink rather than copying the production engine library. Export also
rejects the unused `libflutter_linux_gtk.so` in shell/package outputs so the
application release cannot accidentally duplicate a source-engine library.
The SDK may retain official cached engine
artifacts for SDK tooling; these are not the production embedder engine.
Successful exports use `nix-engine-RUNTIMEHASH-source-VESHELLSHA` tags. Existing
assets are verified, never overwritten.
These prereleases are not marked as the project's latest application release.

`nix/export-release.sh` compresses Nix store exports and splits them into parts
smaller than GitHub's 2 GiB per-asset limit. A checksum manifest binds every
part and metadata describing roots, runtime closure, revisions, and source
commit. GitHub Actions signs a provenance attestation for that manifest using
OIDC; no long-lived signing secret or paid cache service is needed. Attestation
verifies who produced the export, not that the compiled code is bug-free.

To import, independently choose the full source commit you trust and its tag:

```sh
bash nix/import-release.sh "$TRUSTED_COMMIT" "$RELEASE_TAG" package \
  refs/heads/ci/nix-source-release --trust-github-release
```

Run from the repository root of a trusted checkout whose engine pin matches
the selected package release. A mismatched local engine pin fails with an
explanation; the helper never adopts engine pins or helper code from downloaded
package metadata. This Veshell helper accepts `package` only. Engine-only imports
use the standalone repository's helper, obtained from the pinned source:

```sh
ENGINE_SOURCE=$(nix-instantiate --eval --strict --json nix/release.nix -A engineSource | jq -r .)
ENGINE_COMMIT=$(jq -r .revision nix/engine-repository.json)
RAW_ENGINE=$(nix-instantiate --eval --strict --json nix/release.nix -A rawEngine.outPath | jq -r .)
RUNTIME=$(nix-instantiate --eval --strict --json nix/release.nix -A runtime.outPath | jq -r .)
RUNTIME_HASH=${RUNTIME#/nix/store/}
RUNTIME_HASH=${RUNTIME_HASH%%-*}
EXPECTED_ENGINE_OUTPUT="$RAW_ENGINE" EXPECTED_RAW_ENGINE_OUTPUT="$RAW_ENGINE" \
  EXPECTED_RUNTIME_OUTPUT="$RUNTIME" \
  bash "$ENGINE_SOURCE/import-release.sh" "$ENGINE_COMMIT" "nix-engine-$RUNTIME_HASH" \
    engine refs/heads/main --trust-github-release
```

The package helper requires a recent authenticated `gh`, `jq`, `xz`, Nix, and sudo. It
checks the exact repository, workflow, source ref, source commit, manifest
signature, hashes, and part order. After authenticating package metadata, it
checks the engine pins against the local trusted pin and the raw-engine/runtime
paths and nixpkgs revision against `nix/release.nix`. Explicit
`EXPECTED_ENGINE_OUTPUT` (the raw engine), `EXPECTED_RAW_ENGINE_OUTPUT`,
`EXPECTED_RUNTIME_OUTPUT`, and `EXPECTED_NIXPKGS_REVISION` can constrain expected
outputs; they cannot override the trusted engine repository pin or helper source.
It always calls the pinned standalone engine helper to authenticate and import
the dependency release first, even if engine paths already exist locally. All
excluded required paths must be valid and match the installed engine/runtime
closures before invoking `sudo nix-store --import` for application roots.
This is an explicit trust decision: it does not configure a cache or a Nix
trusted public key. Reserve disk space for compressed downloads, decompressed
exports, and the imported store paths. An import does not install or activate
the desktop session.

Use the same pinned entry point to reuse these outputs:

```sh
nix-build nix/release.nix -A package --max-jobs 1 --cores 4
```

## Build

From the repository root:

```sh
nix-build --max-jobs 1 --cores 2
```

The result contains `bin/veshell`, session scripts, systemd user units, portal
descriptors, the matching release engine, AOT shell, and settings/assets.
Builds were verified using nixpkgs `774debe7a0d1` (NixOS 26.05). The default
entry point uses `<nixpkgs>`; callers can supply their own pinned `pkgs`:

```nix
import /path/to/veshell/default.nix { inherit pkgs; }
```

Allow substantial persistent disk space for the SDK, vendored dependencies,
and Rust build. On the small VM, the optimized Rust build took about 15 minutes.

## Inputs And Fixes

- `Cargo.toml` remains the authoritative Flutter version pin.
- `nix/flutter.nix` assembles a Nix-compatible tooling SDK using nixpkgs' Flutter
  builder. `nix/flutter-sdk.json` records verified framework, Dart, and artifact
  hashes. `nix/flutter-tools-lock.json` records the tools' resolved dependencies.
- `nix/engine-repository.json` pins the separate engine repository's immutable
  source archive. That repository owns Flutter's source build, dependency hashes,
  and runtime packaging; Veshell's `nix/engine.nix` is an adapter. The shell explicitly
  selects this build's Dart/frontend, patched platform kernel, and `gen_snapshot`
  through Flutter's local-engine flags. There is no meta-flutter Nix dependency.
  Source-engine support is currently native x86_64 Linux only.
- `nix/dependencies.nix` supplies the verified Cargo vendor hash and Dart Git
  dependency hashes. `nix/pubspec-lock.json` is generated from the shell lockfile.
- `nix/shell.nix` provides the Flutter directory layout that `build_resolvers`
  requires to include `dart:ui`, and creates the offline PulseAudio plugin link.
- `nix/freezed-dart-3.13.patch` backports the removal of `final` formal
  parameters from the locked generator. Freezed 4 contains the published fix,
  but its analyzer requirements conflict with the current lint dependencies.
- The polkit helper path is compiled as `/run/wrappers/bin/polkit-agent-helper-1`.
- The compositor builds with prebuilt shell/engine inputs. Its assets and
  settings use store paths; wrappers supply runtime tools and libraries,
  including dynamically loaded Wayland, PulseAudio, and GStreamer dependencies.
- `nix/sources.nix` includes only Rust, build scripts, packaging assets, settings,
  and Cargo inputs in the compositor source. Dart sources and docs are excluded;
  the external shell derivation still makes Dart changes rebuild the final
  package. Flutter sources exclude build caches and generated Dart code.

The locked PulseAudio 0.0.8 source declares an FFI plugin, has no native GTK
plugin target, and opens `libpulse.so.0` directly from Dart. Its Linux CMake file
only declares the project. GTK is needed to build Flutter's stock Linux runner,
but Veshell uses the Rust embedder instead. The existing shell install copies
the stock runner's `libflutter_linux_gtk.so` with the bundle libraries, and the
package preserves that copy. Those unused libraries and the explicit GTK runtime
reference can potentially be removed without removing PulseAudio support.
Confirm ELF references and actual runtime behavior after that packaging change;
the release exporter refuses those copied GTK engine libraries in the meantime.

Regenerate the shell lock JSON after dependency changes:

```sh
nix-shell -p yq jq --run 'yq -s . src/shell/pubspec.lock | jq -S ".[0]" > nix/pubspec-lock.json'
```

`nix/flutter-sdk-update.nix` exposes hash probes for tools and artifact caches
when updating the SDK pin. Probe hashes are not used by production builds.
Refresh SDK metadata, the standalone engine repository pin, and dependency hashes together when pins
change. The analyzer currently warns that its supported language version is
older than the SDK; code generation, AOT compilation, and Flutter tests pass.

## NixOS Integration

Import the module in the consuming configuration:

```nix
{
  imports = [ /home/nixos/veshell/nix/module.nix ];
  programs.veshell.enable = true;
}
```

`programs.veshell.package` defaults to the local package and can be overridden.
The module registers the Wayland session and user units and enables graphics,
D-Bus, polkit, PipeWire with its PulseAudio compatibility server, and portals.
It does not select a display manager, enable automatic login, or change
networking. NetworkManager, BlueZ, and UPower must be configured separately if
their corresponding shell controls are needed.

Build the system before switching it and retain a working recovery session.
Graphics drivers must be available through NixOS' `/run/opengl-driver` setup.
For nested testing in an existing graphical session:

```sh
VESHELL_BACKEND=winit RUST_LOG=info ./result/bin/veshell
```

## Verification

Completed for the former prebuilt-engine package on the x86_64 VM:

- Pinned SDK and release engine builds; SDK version and offline Linux artifacts.
- Sandboxed release Flutter shell and Rust compositor/package builds.
- All 275 Flutter tests passed in the sandbox.
- ELF dependency checks: no unresolved linked dependencies in the compositor
  or installed shared libraries. Xwayland's version command also succeeds.
- Evaluation-only module checks, including PulseAudio server configuration.

The historical source-engine experiment passed its previous target set; the
new standalone release build is still running. The standalone engine's AOT test
adds a headless compilation and `FlutterEngineCreateAOTData`/collection check;
it does not initialize a running Dart application or verify rendered frames.
The release workflow applies that loader check to Veshell's actual shell
`libapp.so` through `nix/release.nix -A aot`.
The new source-built package, patched ELF tools, AOT test, and release import
must pass hosted verification before distribution is claimed to work.

Commands for module checks and sandboxed Flutter tests:

```sh
nix-instantiate --eval --strict nix/tests.nix --arg pkgs 'import <nixpkgs> {}'
nix-build --no-out-link --max-jobs 1 --cores 2 -E '(import ./default.nix {}).shellBundle.overrideAttrs (_: { doCheck = true; checkPhase = "runHook preCheck; flutter test --no-pub --concurrency 2; runHook postCheck"; })'
```

The Xvfb/llvmpipe smoke test reaches EGL/GLES initialization when Mesa's vendor
configuration is supplied, but stops because the winit backend requires
`EGL_EXT_device_drm` and a render node. It does not establish Flutter AOT startup
or frame presentation. A software-only Xvfb session is not a substitute for a
GPU-capable VM or machine.

Still required: Rust tests, native arm64 builds, GPU-backed frame presentation,
login/logout, audio, polkit authentication, XWayland integration, and portal
screen capture. Add a NixOS runtime test before claiming full session support
or requesting official nixpkgs inclusion.
