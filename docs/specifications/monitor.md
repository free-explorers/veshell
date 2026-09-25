# Monitor

## Description

a Monitor represent a physical display device used to render Veshell

## Properties

int x;  
int y;  
int width;  
int height;  
List<[Screen](screen.md)> screenList; // List of all the screens displayed in the current Monitor  

## State ownership

Monitor state is split across four stores. Each has exactly one writer and a
bounded role; the connector name (`Output::name()` in Rust, `Monitor.name` in
Flutter) is the stable identity key used by all of them.

| State | Store | Single writer | Readers | Persistence |
| ----- | ----- | ------------- | ------- | ----------- |
| **Actual** hardware state (mode, scale, location, connector) | Rust `Output` in `Space` | Rust backend (`drm_backend`, apply/input paths) | Flutter via `monitor_layout_changed` → `connectedMonitorListProvider` → `Monitor`; Rust internals | none (live) |
| **Desired geometry** (mode, `fractionnalScale`, location) | `monitor/<connector>.json` | Dart `MonitorSettingState` (`updateFile`) | Rust `SettingsManager::get_monitor_configuration`, applied at connect | one JSON file per monitor |
| **Shell layout** (screens, `displayMode`) | `MonitorConfigurationState` (Riverpod) | the notifier's own setters; `MonitorManager` calls `removeScreenConfiguration` during hotplug reconcile | Flutter monitor/screen providers | Riverpod JSON persist, **Flutter-only** |
| **Screen/workspace content** | `ScreenState` / `WorkspaceState` | their notifiers | Flutter | Riverpod JSON persist |

Rules:

- Rust's `Output` is authoritative for what the hardware currently is, and is
  read-only to Flutter. Flutter never writes it directly; it writes the desired
  geometry file and Rust applies it best-effort. An apply may be rejected by the
  hardware, in which case the next `monitor_layout_changed` publishes the
  actual state back to Flutter.
- `monitor/<connector>.json` is the only place desired geometry is persisted.
  When the file is absent, `MonitorSettingJson` falls back to the live `Monitor`
  ("reset to detected") without writing anything; it is created by
  `MonitorSettingState` on the first user change. Rust is the single consumer.
- `MonitorConfigurationState` is **Flutter-only**: it is never written to
  `monitor/<connector>.json`, and Rust does not know about screens or split
  direction. It is the authoritative shell layout, keyed by the same connector
  name (persist key `MonitorConfigurationState(<connector>)`).
- The Dart `Monitor` model is a read-only projection of Rust's `Output`. It is
  not persisted and Flutter never writes it. Its live fields are kept alongside
  `MonitorSetting` because the settings UI needs data the desired-geometry file
  does not carry: the modes the display supports (`Monitor.modes`) and the
  currently applied mode (`Monitor.currentMode`), used to reset to detected.
- All four stores key on the connector name, which is stable per physical port
  (`Output::name()` = `"<interface>-<id>"`, e.g. `DP-1`). Identical monitors on
  different ports get different keys, and two connectors cannot collide.
  Replugging a monitor restores its stores by connector name.

There is no migration for existing state: the persistence keys
(`monitor_manager`, `MonitorConfigurationState(<connector>)`) and the
`monitor/<connector>.json` file name are unchanged. A future change to any of
these keys must ship a migration or a version bump.

## Disconnect and reconnect

Monitor state is split between three monitor sets:

- **Known** (`MonitorManager.knownMonitorIds`) — every monitor the shell has
  ever seen, persisted and append-only. It exists so the
  `MonitorConfigurationState` persisted under a connector name can be restored
  when the monitor is plugged back in.
- **Connected** (`connectedMonitorListProvider`) — what the compositor reports
  right now.
- **Active** (`activeMonitorIds`) — the monitors that currently own their
  screens: connected monitors once the first `monitor_layout_changed` event has
  been received, and the known set before that (so startup does not transiently
  release every screen). `monitorForScreen` and `availableScreenList` only
  consider active monitors.

Behaviour:

- **Disconnecting** a monitor removes it from the active set. Its screens leave
  ownership, appear in `availableScreenList` for reassignment, and
  `monitorForScreen` no longer reports the disconnected monitor as their owner.
  The monitor stays in the known registry and its `MonitorConfigurationState`
  is **not** deleted: `ScreenState`/`WorkspaceState` content survives and no
  window or workspace is destroyed.
- **Reconnecting** the same connector makes it active again and restores the
  screens still listed in its retained configuration.
- **Reassigned screens keep their current owner.** If a screen the disconnected
  monitor used was reassigned to another connected monitor while it was away,
  `MonitorManager` drops it from the reconnecting monitor's configuration (the
  single reconcile point, driven by the `connectedMonitorListProvider` diff).
  The reconnecting monitor then restores only the screens nobody else claimed
  and gets a fresh screen if nothing is left.

## Client fractional scale

Native Wayland clients learn the monitor scale through
`wp_fractional_scale_v1`. Rust owns the value: `MetaWindow.scale_ratio` is the
single source of truth and the value written to `set_preferred_scale`.
XWayland is the deliberate exception — its X surfaces have no per-surface
fractional scale and are forced to the global XWayland client scale.

- **At creation** the shell has not placed the window yet, so `scale_ratio`
  defaults to the scale of the output under the pointer, falling back to the
  first connected output (`State::fallback_scale_ratio`). A native client
  therefore never starts at the implicit 1.0 on a scaled monitor.
- **At placement** the shell owns the output choice: when it renders a window
  on a monitor it reports `updateCurrentOutput` with the connector name
  (`Monitor.name` == `Output::name()`). Rust patches `UpdateScaleRatio` with
  that output's scale, replacing the fallback.
- **On scale change** every window whose `current_output` is the changed
  connector is patched with the new scale, so open windows rescale.
