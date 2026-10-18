# NixOS

Veshell is a Nix flake. It supports native **x86_64-linux** only; cross
compilation is not supported.

## Prerequisites

A stock NixOS install ships with the `nix-command` and `flakes` experimental
features disabled, and lets only `root` add substituters. Add both settings to
`configuration.nix` and rebuild before running any of the commands below:

```nix
nix.settings = {
  experimental-features = [ "nix-command" "flakes" ];
  extra-substituters = [ "https://veshell.cachix.org" ];
  extra-trusted-public-keys = [
    "veshell.cachix.org-1:C8J71PCJ1Fx4+4shICPNsSOnGgijVEHZCTrWhbYyjOI="
  ];
};
```

```sh
sudo nixos-rebuild switch
```

Both parts matter:

- `nix run`, `nix profile` and `nixos-rebuild --flake` refuse to run while the
  experimental features are off.
- Nix ignores substituters and public keys configured by an untrusted user, so
  the cache has to be set system-wide. A per-user `cachix use` or
  `--accept-flake-config` does not make the cache usable. Without it, the
  Flutter engine is compiled from source: a long build that currently fails in a
  Python dependency's test suite on recent nixpkgs.

## Try it

```sh
nix run github:free-explorers/veshell
```

## Install it in your profile

```sh
nix profile add github:free-explorers/veshell
```

`nix profile` requires the `nix-command` experimental feature. This puts
`veshell` and `veshell-session` on your `PATH`, but installs no system services or
session integration. Use the module below for a complete session.

## NixOS module

```nix
{
  inputs.veshell.url = "github:free-explorers/veshell";

  # ... in your nixosSystem modules:
  imports = [ inputs.veshell.nixosModules.default ];

  programs.veshell.enable = true;
}
```

The module registers the session and user units and enables what a session needs:
graphics, D-Bus, polkit with its setuid helper, UPower, PipeWire with
PulseAudio, and the Veshell portals. It installs the flake's pinned package by
default; set `programs.veshell.package` to use a different build.

It does not select a display manager, enable automatic login, or change network
configuration. Build before activating and keep a recovery TTY available:

```sh
sudo nixos-rebuild build
sudo nixos-rebuild switch
```

Choose Veshell in an existing display manager, or start it from a TTY:

```sh
XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=veshell veshell-session
```

For nested testing inside an existing graphical session:

```sh
VESHELL_BACKEND=winit RUST_LOG=info nix run github:free-explorers/veshell
```

## The Flutter engine

Veshell builds its matching Flutter engine from source
([flutter-engine-nix](https://github.com/free-explorers/flutter-engine-nix),
pinned in `nix/engine-repository.json`). The engine is published to the `veshell`
Cachix cache, so normal installations substitute it instead of compiling it; the
SDK, shell and Rust binary build locally in a few minutes.

The flake also advertises the cache through `nixConfig`. Nix only applies that
for trusted users, and on a stock NixOS every user except `root` is untrusted,
so configure the cache system-wide as shown in [Prerequisites](#prerequisites).
A per-user `cachix use` and `--accept-flake-config` are both ignored in that
situation.

To build only the engine (for example to warm the cache yourself):

```sh
nix build github:free-explorers/veshell#engine
```

For development, `nix develop` links a **debug** engine (JIT, matching `cargo
run`'s default profile) and sets `VESHELL_FLUTTER_MODE`; `nix develop .#release`
(or `.#profile`) selects another mode. Nix compiles a mode only when it is asked
for, and installs — the package, `nix run` and the NixOS module — always use the
release engine.

The flake passes its `self.rev` (or `self.dirtyRev`) as `VESHELL_BUILD_COMMIT`,
so `veshell --version` identifies the Nix source revision. Evaluating
`default.nix` directly without `buildCommit` reports an unknown commit; pass
the revision explicitly when embedding the package elsewhere.

## Troubleshooting

- **No usable GPU:** check `ls -l /dev/dri`. A real session needs a render node
  and suitable EGL support; in GNOME Boxes, enable 3D acceleration and use
  Virtio/virgl rather than QXL. A nested `VESHELL_BACKEND=winit` run falls back
  to software EGL when no render node exists, but it is slow and clients get
  shared-memory buffers only. Software-only Xvfb is still not a substitute for
  a session.
- **Software rendering is slow:** without a DRM render node Veshell composites
  with software EGL (llvmpipe) and caps the output to 30 fps so the flip-driven
  loop cannot free-run on a virtual display. Set `VESHELL_SOFTWARE_FPS` (for
  example `60`, or `15` on a slow VM) in the session environment to trade
  latency for CPU. Flutter's own full-screen effects, such as the launcher's
  backdrop blur, are still rasterized on the CPU.
- **Loading spinner:** check UPower and the audio server. A missing service can
  block initialization. Run `systemctl status upower.service` and
  `systemctl --user status pipewire-pulse.socket pipewire-pulse.service`.
- **Startup errors / immediate logout:** inspect
  `journalctl --user -b -u veshell.service`. Flutter messages are logged at Rust
  debug level; for the next launch, use
  `RUST_LOG=veshell=debug XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=veshell veshell-session`.
  A log line about a missing DRM GPU, EGL display, or EGL context means the VM
  has no usable graphics stack for a session: enable 3D acceleration. Also make
  sure the session entry runs `veshell-session` (or `veshell --session`) rather
  than a plain `veshell`; a leaked `WAYLAND_DISPLAY`/`DISPLAY` must not select
  the nested backend at login.

## Maintainer notes

- `flake.nix` is the single entry point: `packages`, `nixosModules` and
  `overlays`. Its `nixpkgs` input and the engine packaging pin the same nixpkgs
  revision; keep them in step.
- The engine closure is published to the `veshell` Cachix cache by
  `flutter-engine-nix`'s release workflow. Users substitute it; the SDK, shell
  and package build locally in a few minutes, and a source engine build is only
  the fallback.
- The Flutter SDK/tooling pins (`nix/flutter-sdk.json`,
  `nix/flutter-tools-lock.json`, `nix/engine-repository.json`,
  `nix/dependencies.nix`) are checked against `veshell-packaging`'s
  `release.json` by `scripts/render-recipes.py --check`. Regenerate the shell
  lock JSON with:

  ```sh
  nix shell nixpkgs#yq nixpkgs#jq -c 'yq -s . src/shell/pubspec.lock | jq -S ".[0]" > nix/pubspec-lock.json'
  ```
