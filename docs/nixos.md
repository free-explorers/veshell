# NixOS

Veshell is a Nix flake. It supports native **x86_64-linux** only; cross
compilation is not supported.

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

The package builds its matching Flutter engine from source
([flutter-engine-nix](https://github.com/free-explorers/flutter-engine-nix),
pinned in `nix/engine-repository.json`). The first build compiles the engine and
is expensive; later builds and systems reuse the Nix store. To build only the
engine:

```sh
nix build github:free-explorers/veshell#engine
```

No binary cache is published yet, so `nix run` and `nix profile add` compile
from source the first time.

## Troubleshooting

- **No usable GPU:** check `ls -l /dev/dri`. Graphical testing needs a render node
  and suitable EGL support. In GNOME Boxes, enable 3D acceleration and use
  Virtio/virgl rather than QXL. Software-only Xvfb is not a substitute.
- **Loading spinner:** check UPower and the audio server. A missing service can
  block initialization. Run `systemctl status upower.service` and
  `systemctl --user status pipewire-pulse.socket pipewire-pulse.service`.
- **Startup errors:** inspect `journalctl --user -b -u veshell.service`. Flutter
  messages are logged at Rust debug level; for the next launch, use
  `RUST_LOG=veshell=debug XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=veshell veshell-session`.

## Maintainer notes

- `flake.nix` is the single entry point: `packages`, `nixosModules` and
  `overlays`. Its `nixpkgs` input, `nix/release.nix` and the engine packaging all
  pin the same nixpkgs revision; keep them in step.
- `nix/release.nix` mirrors the flake's pinned roots for the packaging
  repository's Nix workflow, which is not flake-aware yet. Prefer the flake.
- The Flutter SDK/tooling pins (`nix/flutter-sdk.json`,
  `nix/flutter-tools-lock.json`, `nix/engine-repository.json`,
  `nix/dependencies.nix`) are checked against `veshell-packaging`'s
  `release.json` by `scripts/render-recipes.py --check`. Regenerate the shell
  lock JSON with:

  ```sh
  nix shell nixpkgs#yq nixpkgs#jq -c 'yq -s . src/shell/pubspec.lock | jq -S ".[0]" > nix/pubspec-lock.json'
  ```
