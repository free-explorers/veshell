# NixOS packaging

Veshell supports native **x86_64-linux** Nix builds and NixOS session integration.
The package uses a source-built Flutter engine from
[flutter-engine-nix](https://github.com/free-explorers/flutter-engine-nix), with
matching Dart/AOT tooling. This is project packaging, not an official nixpkgs
package. Arm64 and cross compilation are not supported yet.

Run build and import commands from the Veshell repository root.

## Build and install

Use the pinned package set in `nix/release.nix` for the tested build. If the
engine is not already in the Nix store, Nix will build it from source, which is
expensive. [Import its published closure first](#reuse-the-engine-build) to avoid
that build.

```sh
nix-build nix/release.nix -A package --out-link result --max-jobs 1 --cores 4
nix-build nix/release.nix -A aot --no-out-link --max-jobs 1 --cores 2
```

The second command checks that the final installed AOT library loads with its
engine. It does not start a graphical session.

For a user-profile installation:

```sh
nix profile add "$(readlink -f result)"
```

Enable Nix's `nix-command` experimental feature to use `nix profile`.
This provides `veshell` and `veshell-session` through `~/.nix-profile/bin`, but
does **not** enable the system services or polkit helper required for a complete
session. Use the NixOS module below for system integration.

`default.nix` uses the caller's `<nixpkgs>` instead of the release pin. Advanced
callers can supply their own package set:

```nix
import /path/to/veshell/default.nix { inherit pkgs; }
```

## NixOS integration

Add the module to your NixOS configuration, using your checkout's location:

```nix
{
  imports = [ /path/to/veshell/nix/module.nix ];

  programs.veshell = {
    enable = true;
    package = (import /path/to/veshell/nix/release.nix).package;
  };
}
```

The explicit package selects the tested release package set. If omitted, the
module builds against your system's `pkgs`. Keep the package expression rather
than a bare store path: NixOS needs its `providedSessions` metadata.

The module registers the session and user units, and enables graphics, D-Bus,
polkit and its setuid helper, PipeWire with PulseAudio support, UPower, and
portals. UPower and a PulseAudio-compatible server are required by shell startup.
Configure NetworkManager and BlueZ separately if their controls are needed.

It does not select a display manager, enable automatic login, or change network
configuration. Build before activating, and keep a recovery TTY available.
Run these outside the Veshell checkout to avoid replacing its package `result`
link with the system build:

```sh
sudo nixos-rebuild build
sudo nixos-rebuild switch
```

Choose Veshell in an existing display manager, or start it from a local TTY:

```sh
XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=veshell veshell-session
```

For nested testing inside an existing graphical session:

```sh
VESHELL_BACKEND=winit RUST_LOG=info ./result/bin/veshell
```

## Reuse the engine build

The engine repository publishes attested Nix closures through GitHub Releases.
Importing one reuses the source-build output; it does not replace the source
derivation or configure an automatic binary cache.

You need Nix, a recent authenticated `gh`, `jq`, `xz`, and sudo. Allow space for
the compressed download, decoded archive, and imported store paths; the helper
also reserves 2 GiB. The tools can be made available with
`nix-shell -p gh jq xz`.

Resolve the required release from this checkout's immutable engine pin:

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

`--trust-github-release` is an explicit trust decision. The helper verifies the
exact engine repository, workflow, source ref/commit, checksum manifest, asset
hashes, metadata, and expected outputs before invoking `sudo nix-store --import`.
Attestation establishes provenance, not that the code is bug-free. Import alone
does not install Veshell or activate a session.

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
- **Stalled downloads:** retry the build with
  `--option connect-timeout 10 --option stalled-download-timeout 30 --option download-attempts 2`.

## Verification

Verified on x86_64 NixOS:

- Hosted source-engine build, runtime packaging, synthetic AOT checks, and
  attested engine export/import.
- Sandboxed shell and Rust release builds, user-profile installation, NixOS
  system build, and activation.
- AOT loading of the final installed `libapp.so`, native executable dependency
  resolution, and module/source-isolation checks.
- First graphical startup in GNOME Boxes with Virtio/virgl.

Run the packaging checks with:

```sh
nix-instantiate --eval --strict nix/tests.nix --arg pkgs 'import <nixpkgs> {}'
nix-build nix/release.nix -A aot --no-out-link --max-jobs 1 --cores 2
```

Full login/logout, audio playback, polkit prompts, XWayland, and portal capture
remain unverified. Rust tests and Flutter tests have not been rerun for the final
source-engine integration; these builds disable the normal test phases.

## Maintainer notes

- The packaging release manifest lives in
  `free-explorers/veshell-packaging` (`release.json`). `Cargo.toml`,
  `nix/flutter-sdk.json` and `nix/engine-repository.json` here must agree with
  it; the packaging repo's
  `scripts/render-recipes.py --check --veshell-src <checkout>` enforces that.
  `nix/flutter-sdk.json` and `nix/flutter-tools-lock.json` hold the verified
  SDK/tooling metadata.
- `nix/engine-repository.json` pins the independent engine packaging source.
  The shell explicitly uses its matching frontend, platform kernel, and
  `gen_snapshot`; matching version strings alone are insufficient.
- SDK, engine, shell, and compositor are separate derivations.
  `nix/sources.nix` excludes caches/generated Dart and keeps documentation and
  Dart sources out of the Rust source input.
- GTK is needed for Flutter's Linux bundle build, but its unused runner library
  is removed from the installed shell. Veshell references the small embedder
  runtime rather than the full engine toolchain.
- The polkit helper path is compiled as `/run/wrappers/bin/polkit-agent-helper-1`.
- Refresh SDK metadata, the engine pin, and dependency hashes together when
  changing toolchain/dependency pins. `nix/flutter-sdk-update.nix` provides SDK
  hash probes. A lockfile git-ref change is also a hash change: re-verify the
  affected `nix/dependencies.nix` entry with
  `nix-prefetch-git --url <url> --rev <resolved-ref>`. Regenerate the shell
  lock JSON with:

```sh
nix-shell -p yq jq --run 'yq -s . src/shell/pubspec.lock | jq -S ".[0]" > nix/pubspec-lock.json'
```

The `Nix Package Release` workflow
(`.github/workflows/nix-package-release.yml`) is dispatch-only for now. It
belongs in `free-explorers/veshell-packaging` alongside the other channels and
has not been moved yet. It and the application export/import helpers are
prepared but have not been verified end-to-end. Application publishing is not
required for installation. If used, application exports exclude the separately
published engine closure, and importing requires verification of both
repositories. No Veshell application release is currently published; do not
treat those helpers as a tested installation path.
