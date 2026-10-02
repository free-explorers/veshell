# NixOS packaging status

This checkout contains **preparatory, unbuilt Nix support**, not an official
nixpkgs package or a ready-to-install release. The running system has not been
changed. Official availability requires review and acceptance by the Veshell
and nixpkgs maintainers.

## What is implemented

- `nix/shell.nix` builds a release Flutter shell separately, including code
  generation and a NixOS polkit-helper path substitution before AOT compilation.
- `nix/package.nix` builds the Rust compositor with explicit prebuilt shell and
  engine inputs. It installs assets, user units, portals and a Wayland session,
  patches ELF paths, and wraps runtime tools and GStreamer plugins.
- `nix/module.nix` exposes `programs.veshell.enable` and a required
  `programs.veshell.package`, registers the login session and user units, and
  configures graphics, D-Bus, polkit, PipeWire and portals. It does not select a
  display manager, enable automatic login, or change networking.
- The existing development build remains the default. Setting
  `VESHELL_PREBUILT_SHELL` skips SDK installation and shell compilation;
  `VESHELL_ENGINE_DIR` supplies `flutter_embedder.h` and the profile-specific
  engine library without a download. The caller must ensure that the AOT shell
  and engine have matching revisions and architectures.
- Compile-time `VESHELL_DATA_DIR` and `VESHELL_LIB_DIR` allow installation in
  the Nix store without relying on `/usr` paths or checkout assets.

## Inputs still required

The authoritative SDK pin remains `Cargo.toml`. Supply a Nix-compatible SDK
matching that pin with offline Linux artifacts, rather than an ordinary
unpatched Flutter Git checkout. The package rejects the older SDK available
in this VM's nixpkgs.

The following are not supplied yet:

- A derivation and verified hashes for that matching SDK and embedder engine.
- `pubspec.lock` converted to a Nix attribute set for `pubspecLock`, and real
  `gitHashes` for its Git dependencies, as required by nixpkgs' Flutter builder.
- The real `cargoHash` for Cargo's vendored dependencies, including Smithay.

There are deliberately no placeholder hashes or impure network builds. The
expressions are not turnkey until these inputs are added and verified.

The shell bundle must contain `lib/libapp.so`, `data/icudtl.dat`, and
`data/flutter_assets`. The embedder-engine input must contain
`flutter_embedder.h` and `release/libflutter_engine.so`. Use the engine revision
from the pinned SDK's `bin/internal/engine.version`, not the unused Rust
engine-revision constant.

## Integration Once Built

Once `veshellPackage` is a successfully built package from `nix/package.nix`,
the consuming NixOS configuration can use:

```nix
{
  imports = [ /home/nixos/veshell/nix/module.nix ];
  programs.veshell = {
    enable = true;
    package = veshellPackage;
  };
}
```

`veshellPackage` above is a caller-provided binding, not an existing nixpkgs
attribute. Retain or configure a Wayland-capable display manager separately.
Build the system before switching it, and retain a working session for recovery.

## Verification And Upstreaming

Run evaluation-only module checks with:

```sh
nix-instantiate --eval --strict nix/tests.nix --arg pkgs 'import <nixpkgs> {}'
```

These checks use a mock package; they do not test binaries, ELF fixups, polkit
authentication, or a graphical session. A source build, `cargo check`,
`cargo test`, Flutter tests, and graphical runtime tests are still required.
The initial VM has less than 1 GB free in a tmpfs-backed live environment,
which is insufficient for the SDK and full Rust/Flutter build. Provision a
persistent build disk with substantial free space (tens of GB recommended).

Before requesting official nixpkgs inclusion:

1. Finish all pinned SDK/engine and dependency inputs and build in the sandbox.
2. Test from outside the checkout, then test login/logout, polkit authentication,
   XWayland, portals and screen capture in a GPU-capable NixOS VM or machine.
3. Add a NixOS runtime test and a maintainer, choose a pinned source revision,
   and adapt the package/module to current nixpkgs contribution conventions.
4. Submit the offline-build changes to Veshell and the package/module to
   nixpkgs for review. Neither submission nor acceptance has occurred here.
