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
nix run github:free-explorers/veshell/latest-release
```

## Install it in your profile

```sh
nix profile add github:free-explorers/veshell/latest-release
```

`nix profile` requires the `nix-command` experimental feature. This puts
`veshell` and `veshell-session` on your `PATH`, but installs no system services or
session integration. Use the module below for a complete session.

## NixOS module

```nix
{
  inputs.veshell.url = "github:free-explorers/veshell/latest-release";

  # ... in your nixosSystem modules:
  imports = [ inputs.veshell.nixosModules.default ];

  programs.veshell.enable = true;
}
```

The module registers the session and user units and enables what a session needs:
graphics, D-Bus, polkit with its setuid helper, UPower, PipeWire with
PulseAudio, and the Veshell portals. By default it builds the compositor with
your system's nixpkgs, while the Flutter SDK, shell and engine stay on the
versions Veshell pins; set `programs.veshell.package` to use a different build.

The compositor loads the system's graphics driver from `/run/opengl-driver`
into its own process, and a driver built against a newer glibc than the
compositor's fails to load. That is why the module does not install the
flake's `packages.x86_64-linux.default`, which is built entirely on Veshell's
pinned nixpkgs: on a system whose nixpkgs is newer, it exits at startup with
`Egl(DisplayNotSupported)`. The same applies to `nix run` and `nix profile`;
`overlays.default` builds like the module.

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
VESHELL_BACKEND=winit RUST_LOG=info nix run github:free-explorers/veshell/latest-release
```

## The Flutter engine

Veshell builds its matching Flutter engine from source
([flutter-engine-nix](https://github.com/free-explorers/flutter-engine-nix), a
flake input pinned in `flake.lock`). The engine is published to the `veshell`
Cachix cache, so normal installations substitute it instead of compiling it.
Each release also publishes the flake's package and the shell bundle, and moves
the `latest-release` branch to the release commit: `nix run` and
`nix profile add` from `latest-release` substitute the package, and the module
and the overlay substitute the bundle and build only the compositor, which
depends on your nixpkgs, in a few minutes. `nix flake update` follows new
releases. A reference to `main` (`github:free-explorers/veshell`) gets the
latest changes instead, and builds them locally.

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
- **`Egl(DisplayNotSupported)` at startup:** EGL could not load any driver,
  so no platform is available. Check that `hardware.graphics.enable` is set
  (the module sets it) and that
  `/run/opengl-driver/share/glvnd/egl_vendor.d/` is not empty. If it is not
  empty, the driver probably failed to load because it was built against a
  newer glibc than Veshell: use the module or `overlays.default`, which build
  the compositor with your system's nixpkgs, rather than `nix run` or
  `nix profile`.
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
  `overlays`. Every pin of the Nix build is in `flake.lock`: `nixpkgs`, and
  `flutter-engine-nix` with its own `nixpkgs`, which this flake must not make
  follow its own: the cache holds the engine built from flutter-engine-nix's
  lock only. `nix/engine-lock.nix` reads the same lock for evaluation without
  flakes. The Flutter SDK and shell bundle always build on
  that input (`flutterPkgs` in `default.nix`); the module and overlay build the
  compositor (`nix/package.nix`) with the consumer's nixpkgs, so it must keep
  building on current nixpkgs-unstable and the latest stable release.
  `.github/workflows/nix-unstable.yml` builds it on the head of
  nixpkgs-unstable every week and on pull requests that change the Nix build
  or `Cargo.lock`.
- The engine closure is published to the `veshell` Cachix cache by
  `flutter-engine-nix`'s release workflow, and each release's package and shell
  bundle by the `nix` job of `.github/workflows/release.yml`, which then moves
  `latest-release` to the release commit. A source engine build is only the
  fallback.
- `.github/workflows/update-nixpkgs.yml` opens a pull request every week that
  moves the `nixpkgs` input. `flutter-engine-nix` is bumped by hand, or by
  Complete Flutter Bump: its nixpkgs only moves with a new engine build.
- The Flutter SDK/tooling pins (`nix/flutter-sdk.json`,
  `nix/flutter-tools-lock.json`, the `flutter-engine-nix` node of `flake.lock`,
  `nix/dependencies.nix`) are checked against `veshell-packaging`'s
  `release.json` by `scripts/render-recipes.py --check`. Regenerate the shell
  lock JSON with:

  ```sh
  nix shell nixpkgs#yq nixpkgs#jq -c 'yq -s . src/shell/pubspec.lock | jq -S ".[0]" > nix/pubspec-lock.json'
  ```
