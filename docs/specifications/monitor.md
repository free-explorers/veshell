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
| **Desired geometry** (mode, `fractionnalScale`, location, transform, mirror target) | `monitor/<connector>.json` | Dart `MonitorSettingState` (`updateFile`) | Rust `SettingsManager::get_monitor_configuration`, applied at connect | one JSON file per monitor |
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
  name (persist key `MonitorConfigurationState(<connector>)`). Its `screenList`
  is kept summing to a fixed total; screens are redistributed proportionally
  when one is added or removed, so repeated edits do not drift.
- The Dart `Monitor` model is a read-only projection of Rust's `Output`. It is
  not persisted and Flutter never writes it. Its live fields are kept alongside
  `MonitorSetting` because the settings UI needs data the desired-geometry file
  does not carry: the modes the display supports (`Monitor.modes`) and the
  currently applied mode (`Monitor.currentMode`), used to reset to the default
  location and the detected configuration.
- All four stores key on the connector name, which is stable per physical port
  (`Output::name()` = `"<interface>-<id>"`, e.g. `DP-1`). Identical monitors on
  different ports get different keys, and two connectors cannot collide.
  Replugging a monitor restores its stores by connector name.

There is no migration for existing state: the persistence keys
(`monitor_manager`, `MonitorConfigurationState(<connector>)`) and the
`monitor/<connector>.json` file name are unchanged. A future change to any of
these keys must ship a migration or a version bump.

## Arrangement

Monitors are positioned relative to each other through the **Arrange Monitors**
entry in the Monitors settings group. Expanding it (`ExpandableSearchResult`)
shows the inline `MonitorArrangementEditor`: a canvas of draggable monitor
rectangles plus `Reset to default` / `Apply` actions.

- The editor reads the live `Monitor` projection plus the desired geometry file
  and lays every connected monitor out proportionally to its **logical** size
  (`MonitorMode` size divided by `fractionnalScale`).
- The editor only manipulates **relative** positions: the arrangement is
  normalised so its bounding-box top-left sits at `(0, 0)` for display and
  dragging, independently of the current absolute base.
- Dragging stages positions locally; nothing is written while dragging. A
  drag is tracked by the canvas itself (one gesture recognizer), so it survives
  the page rebuilding while the overlap warning appears.
- `Reset to default` stages only the **locations** in the compositor's default
  left-to-right layout (from the origin, using each monitor's current logical
  size). Mode and scale overrides are preserved.
- Applying **transposes** the relative layout to a `(0, 0)`-based absolute
  location and writes every monitor whose absolute position changed, through
  the existing `MonitorSettingState.setLocation`, so the single-writer rule for
  `monitor/<connector>.json` above is preserved. Rust applies the file live and
  publishes the actual geometry back through `monitor_layout_changed`.
- Overlapping monitors are rejected on apply: the editor warns and disables the
  button, while touching edges is allowed.
- No new persistence: the arrangement is derived, only absolute `location`
  values are stored.

## Transform

A monitor's display can be transformed with the full set of eight output
transforms: `Normal` (the default), the quarter/half/three-quarter clockwise
rotations (`Rotate90`, `Rotate180`, `Rotate270`) and the mirrored variants
(`Flipped`, `Flipped90`, `Flipped180`, `Flipped270`). The choice is a
desired-geometry field (`transform`) written by `MonitorSettingState.setTransform`
and read by Rust as part of `MonitorConfiguration`.

- Rust maps it to the live `Output` transform (`Rotate90` → `Transform::_90`,
  `Flipped90` → `Transform::Flipped90`, and so on) through
  `change_current_state`, both at connect (`connector_connected`) and on live
  re-apply (`State::apply_monitor_configuration_to_output`). Hardware rejection
  is best-effort like every other desired field: the applied transform is
  published back through `monitor_layout_changed`.
- The Flutter view is sized to the **transformed** logical size: `add_view` and
  `resize_view` use `output.current_transform().transform_size(mode)`, so the
  quarter-turn variants lay out a portrait surface and the compositor's output
  transform maps it onto the physical framebuffer. The mode itself is unchanged.
- The nested (winit) backend does not support output transforms
  (`Backend::SUPPORTS_OUTPUT_TRANSFORM == false`): its `Flipped180` correction is
  never overwritten by the setting.
- The arrangement canvas transposes the monitor's logical size for the
  quarter-turn transforms (`MonitorTransform.isTransposed`), so the editor shows
  the same footprint Rust lays out.
- `transform` is `#[serde(default)]` on the Rust side and defaults to normal on
  the Dart side, so files written before the field existed keep working.

## Mirroring

A monitor can be configured to **mirror** another monitor by setting `mirrorOf`
to the target's connector name in its own `monitor/<connector>.json`. The shell
then presents the target's content on it. The field is optional; absent means a
regular display.

- Resolution is dynamic and one level deep (`State::mirror_source`): the target
  must be connected **and** must itself be a regular display (it must not have a
  `mirrorOf` setting of its own). In any other case — target absent, target is
  self, or the target is itself a follower — the monitor **falls back to a
  regular display**. This is re-evaluated on every connect, disconnect and
  configuration change, so unplugging the target simply restores the follower's
  own desktop.
- Rendering is a native compositor mirror: the DRM render path resolves the
  source output and presents the **source's Flutter frame** (its backing-store
  slot), scaled to the follower's own output geometry. Each output keeps its own
  view; the follower's own Flutter view is suppressed.
- Input follows the mirror: `view_id_under_pointer` routes to the source's view,
  and pointer coordinates are mapped proportionally from the follower's logical
  box to the source's so a click lands at the same relative spot.
- On the Flutter side `effectiveMirrorSource` reproduces the same resolution
  from the desired files and the connected list. A mirroring monitor renders
  nothing (its frame is composited by Rust), is not given a fallback screen by
  `MonitorManager`, and is excluded from the arrangement canvas. Its retained
  screen configuration is untouched and is restored when the mirror is turned
  off.
- `mirrorOf` is `#[serde(default)]` on the Rust side and nullable on the Dart
  side, so files written before the field existed keep working.

## Change confirmation

Display settings that can leave a monitor unusable — mode (resolution/refresh),
fractional scale and transform — go through a confirmation guard instead of
being written directly.

- `MonitorSettingState` routes those setters through
  `MonitorSettingChangeConfirmation.propose`: the new desired geometry is
  written immediately (so Rust applies it live) and a timer is started
  (`monitorSettingConfirmationTimeout`, 15 s by default).
- The prompt is mounted in every monitor's `MaterialApp.builder`
  (`MonitorSettingChangeConfirmationOverlay`), above the capture prompts, so it
  is visible on a still-working monitor even when the changed one is unusable.
  `Keep` cancels the timer; `Revert` — or the timer expiring — writes the last
  confirmed geometry back, which Rust applies live and republishes through
  `monitor_layout_changed`.
- The rollback timer lives in the notifier, not the widget, so it fires even if
  no view can draw the prompt.
- Location and mirror changes are written directly: the arrangement editor
  already has its own apply/cancel step, and a mirror is visible and instantly
  reversible.

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
- **An emptied monitor stays empty while connected.** Deleting every screen of
  a monitor from the screen menu is an intentional user action and is not
  immediately undone. Because the screen configuration menu lives inside a
  screen, an empty monitor renders a monitor-level fallback (`EmptyMonitor`)
  that creates a screen or adopts an unowned one, so the monitor is never a
  dead end. A screen is also created automatically for a monitor the shell has
  never configured, or for a monitor left with no screens when it (re)connects;
  restarting the shell therefore refills an intentionally emptied monitor
  rather than leaving it unusable.

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
