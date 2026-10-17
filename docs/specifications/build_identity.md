# Build identity and version reporting

## Description

Veshell must be able to report which code an installed binary was built from,
so a bug report can distinguish a release from a stale package, a source build
or a dirty checkout.

This milestone covers the command-line surface only:

```
veshell --version
```

It reports the identity embedded in the **installed binary**. It intentionally
does not inspect the package manager, the source tree or a running session. An
in-shell About surface is out of scope for this milestone.

## Identity fields

| Field | Source | Example |
|---|---|---|
| Version | Cargo package version (`CARGO_PKG_VERSION`) | `0.1.5` |
| Commit | `VESHELL_BUILD_COMMIT` build input | `31d7d01` or `31d7d01-dirty` |
| Channel | `VESHELL_BUILD_CHANNEL` build input | `beta`, `beta.1` or `stable` |
| Build | Flutter runtime mode already used by the build script | `release` |

The commit and channel are optional. A build that does not receive them
reports `commit unknown`; it never guesses from the checkout or from the
package manager. The Cargo build script must not run `git`: release tarballs
and Nix source sets have no `.git`, and a guess would identify the wrong tree
or break a hermetic build. A build timestamp is deliberately excluded: it is
not reproducible and does not identify source.

The fields are embedded at compile time and are not read from the environment
at runtime.

## Command line

```
Usage: veshell [OPTIONS]

Options:
      --session   Start as a real session, using the DRM backend
  -V, --version   Print the installed binary's version and build identity
  -h, --help      Print this help
```

`--version` and `--help` are handled before logging, the font warmup thread,
rlimit changes, backend selection, DRM/logind and Flutter initialization.
They exit successfully without a display, a session bus or a running
compositor. Unknown options are errors; a typo must not silently start a
compositor on the current VT. `-v` is intentionally not a version flag; it is
reserved for verbosity, and Veshell configures logging through `RUST_LOG`.

## Packaging

CI and packagers should pass `VESHELL_BUILD_COMMIT` (and, when known,
`VESHELL_BUILD_CHANNEL`) from the source revision they actually built. The
value must come from the build input, not from release metadata that could
describe a different tree. Allowed characters are ASCII letters, digits, `.`,
`-`, `_` and `+`; a dirty checkout may append `-dirty`.

The automatic `make` path supplies a best-effort short revision, while Nix
passes the flake revision when available. Direct `cargo build`/`cargo run`
builds report an unknown commit unless the variables are set explicitly.
Source tarballs and other checkout-free builds report an unknown commit unless
their recipe supplies one. The `veshell-packaging` recipes must export the
variables from their source pin; until they do, packages built there report
`commit unknown`.

## Non-goals

- No in-shell About page or dialog in this milestone.
- No network update check and no telemetry.
- No claim that a self-reported version proves the package manager or the
  downloaded artifact is authentic.

## Acceptance criteria

- A release build's reported version and commit match its tag and source
  revision.
- A prerelease build reports its prerelease/channel when packaging supplies it.
- `veshell --version` exits 0 without initializing the backend or Flutter and
  works with no `DISPLAY`, `WAYLAND_DISPLAY` or session bus.
- `veshell --help` lists the supported options.
- Unknown options exit non-zero and do not start the compositor.
