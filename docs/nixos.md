# NixOS packaging

The release package builds in the Nix sandbox on x86_64 NixOS. This is local
packaging support, not an official nixpkgs package. A complete graphical login
session has not yet been verified, and the running VM's desktop configuration
has not been changed.

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
