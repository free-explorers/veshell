# Environment variables

## Description

Users define environment variables for their session in Settings → System →
Environment variables (Overview Settings, like the other groups). They are
stored under `environment.variables` in `settings.json` as a `NAME → value`
object and apply to every application Veshell launches.

The compositor builds the launch environment in the
`get_environment_variables` platform callback
(`src/embedder/flutter_engine/platform_channel_callbacks/get_environment_variables.rs`):
it starts from the built-in session variables, layers the user's variables on
top, and both returns the map to the shell and pushes it through the
`set_environment_variables` event. The shell forwards every entry to
`systemd-run --setenv=…` in `AppLaunch`, so tracked launches observe the user's
values regardless of the systemd user manager's own session environment.

The compositor also applies the variables to its **own process environment**
(`State::new` / `apply_veshell_settings`) so anything it spawns inherits them,
and imports them — together with the built-in session variables — into the
session's systemd user manager and the D-Bus activation environment
(`spawn_environment_import` in the DRM backend). That is what reaches portals,
xdg-autostart units and applications started outside the shell. The names are
passed to the import shell as positional arguments, not interpolated, so a
hand-edited `settings.json` cannot inject shell syntax.

## Split

| Concern | Owner |
| --- | --- |
| Storing `environment.variables` and editing it | Shell (Flutter) |
| Merging user variables into the launch environment | Compositor |
| Applying them to the compositor process and importing them into the session | Compositor (DRM backend) |
| Starting applications with that environment | Shell (Flutter), `AppLaunch` |
| Built-in session variables (`WAYLAND_DISPLAY`, `DISPLAY`, `XDG_*`, `GDK_BACKEND`, `QT_QPA_PLATFORM`) | Compositor |

## Precedence

A user variable overrides the compositor's built-in value for the same name —
that is the point of the setting (toolkit theme through `QT_QPA_PLATFORM` or
`QT_STYLE_OVERRIDE`, driver selection, `XDG_*`, …).

`WAYLAND_DISPLAY` and `DISPLAY` are the exception. They are derived from the
socket and XWayland display this compositor actually owns, so a user value is
ignored: overriding them would leave every launched application unable to
connect. They are therefore always reported from the live session.

## Scope and timing

- Changes affect applications and services started **after** the setting is
  saved. Already-running applications keep their environment, and a
  D-Bus-activated service that is already running keeps the environment it was
  activated with until it restarts.
- On a change the compositor updates its own environment and re-imports the
  names into the systemd user manager and the D-Bus activation environment, so
  new activations, xdg-autostart units and external launchers pick up the new
  values without a logout. A removed variable is unset in the systemd user
  manager too; D-Bus activation has no portable "unset", so a D-Bus-activated
  service that already ran keeps the old value until the next session. A change
  that alters nothing skips the re-import entirely.
- The nested (winit) backend never imports into the host session: it is a
  development backend, not a session compositor.
- Names must be portable POSIX names (`[A-Za-z_][A-Za-z0-9_]*`); the editor
  rejects malformed or duplicated names before writing, and the compositor skips
  any malformed name it finds in a hand-edited file.

## Invariants

- A user setting never overrides `WAYLAND_DISPLAY` or `DISPLAY`.
- The reported launch environment always contains the built-in session
  variables, with user values layered on top.
- Only valid, non-duplicated names reach `settings.json`, and only valid names
  are forwarded to the launch environment or the session import.
- A variable removed from the settings is unset from the compositor's
  environment and from the systemd user manager; a removed override of a
  built-in variable (`XDG_*`, `GDK_BACKEND`, `QT_QPA_PLATFORM`) is restored to
  its default instead.
- A settings change never mutates the environment of an already-running
  application or service.
- The nested backend does not touch the host session's environment.
