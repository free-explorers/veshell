# NixOS packaging

The release package builds in the Nix sandbox on x86_64 NixOS. This is local
packaging support, not an official nixpkgs package. A complete graphical login
session has not yet been verified, and the running VM's desktop configuration
has not been changed.

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

For fast installation, build these derivations in project CI and publish their
outputs to a project-owned Nix binary cache, such as Cachix or a self-hosted
cache. Pin CI's nixpkgs revision and build each supported architecture. Start
with x86_64 Linux and add aarch64 once verified. Document the cache URL and
public signing key; enabling that cache must be an explicit user trust decision.
Keep signing secrets outside the repository.

The cache distributes outputs of the source-build derivations; do not replace
the source build with a hardcoded download of a project-hosted `.so`. When a
matching cached output is unavailable, Nix must retain the source-build path.
After nixpkgs inclusion, use the official NixOS binary cache where builds are
available; the project cache serves development and releases not yet cached
there. Cache availability is not guaranteed for every revision or platform.

This is the agreed target, not a claim that migration or CI/cache setup is
complete. The verified package described below still uses meta-flutter's engine.
Source-engine compilation, matching shell rebuilds, runtime verification, and
cache publishing remain implementation work.

### Hosted Runner Experiment

`Nix Engine Experiment` builds only the source release engine, independently of
the currently verified meta-flutter-based package. Its entry point is
`nix/engine-experiment.nix`, with a hash-pinned nixpkgs revision. The first run
is triggered by publishing changes on `ci/nix-engine-experiment`; manual dispatch
is available once the workflow exists on the repository's default branch.

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
- `nix/flutter.nix` assembles a Nix-compatible SDK using nixpkgs' Flutter
  builder. `nix/flutter-sdk.json` records verified framework, Dart, artifact,
  and embedder-engine hashes. `nix/flutter-tools-lock.json` records the tools'
  resolved dependencies. No older SDK or source engine compilation is used.
- The release embedder engine comes from meta-flutter at the SDK's exact engine
  revision. x64 was built; arm64 input archives were hash-verified and evaluated,
  but a native arm64 application build has not been tested.
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

Regenerate the shell lock JSON after dependency changes:

```sh
nix-shell -p yq jq --run 'yq -s . src/shell/pubspec.lock | jq -S ".[0]" > nix/pubspec-lock.json'
```

`nix/flutter-sdk-update.nix` exposes hash probes for tools and artifact caches
when updating the SDK pin. Probe hashes are not used by production builds.
Refresh SDK metadata, engine hashes, and dependency hashes together when pins
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

Completed on the x86_64 VM:

- Pinned SDK and release engine builds; SDK version and offline Linux artifacts.
- Sandboxed release Flutter shell and Rust compositor/package builds.
- All 275 Flutter tests passed in the sandbox.
- ELF dependency checks: no unresolved linked dependencies in the compositor
  or installed shared libraries. Xwayland's version command also succeeds.
- Evaluation-only module checks, including PulseAudio server configuration.

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
