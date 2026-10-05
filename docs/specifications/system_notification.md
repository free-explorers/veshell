# System notifications

## Description

System notifications are the shell's own transient alerts for state it owns or
observes directly: the output volume, the display brightness and the battery
charge. They reuse the [Notification](notification.md) pipeline's anchored
popups but are **synthesized** (`isSynthetic`) and therefore never enter the
persisted history and never emit D-Bus signals — a volume OSD belongs on screen
for a moment, not in the notification center.

They are intentionally separate from the freedesktop notification server:
nothing here originates from a client, and no sender identity or routing is
involved. The popup always lands on the focused screen.

## What triggers one

| Alert | Source | Transport |
|---|---|---|
| Volume / mute | Shell hotkeys (`system.increaseVolume`, `system.decreaseVolume`, `system.muteVolume`) | In-process: the handler calls `SystemNotificationManager` directly |
| Brightness | The compositor's brightness authority, on both the hardware function keys and the shell's `adjust_brightness` request | `brightness_changed { fraction }` platform event |
| Battery low / critical | UPower system battery | In-process: `BatteryNotification` watches the device |

Only the volume/brightness **keys** raise an OSD. A change made by another
client (a mixer, an application, the Helm slider) updates the same state but does
not pop: the alert is feedback for the key that was just pressed, not a mirror of
every value.

Brightness is owned by the compositor (see [Monitor](monitor.md) and
`src/embedder/brightness/`): the function keys are swallowed there so they keep
working while the shell is unfocused and while the panel is idle-dimmed. The
compositor therefore reports the level it settled on rather than letting the
shell guess it.

## Presentation

`SystemNotificationManager` (`src/shell/lib/notification/provider/`) builds a
`Notification` per alert and pushes it to the focused screen's
`NotificationChannel`, the same one used for unresolved D-Bus notifications:

- It is `isSynthetic: true`, so it is excluded from `NotificationList` and from
  the unread/workspace-dot state.
- Each `SystemNotificationKind` has a **stable negative id**, so re-showing the
  same kind replaces its live popup in place (holding a volume key does not stack
  one popup per step). Two kinds — volume and brightness — coexist under their
  own ids. Negative ids never collide with the positive ids the notification
  manager assigns.
- If focus moved since the last popup, the previous one is torn down from its old
  channel first.
- Volume and brightness expire after two seconds; a low-battery warning after
  eight; a critical-battery warning does not expire on its own (D-Bus `0`
  timeout) so it stays until dismissed.

The freedesktop `value` hint carries the level (`0..100`) and renders as a
progress bar in `NotificationWidget`. A `category` hint of the form
`x-veshell.*` selects the alert's icon without a desktop entry:

| Category | Bar | Icon |
|---|---|---|
| `x-veshell.volume` | volume percentage | `volume-high` |
| `x-veshell.volume-muted` | empty | `volume-off` |
| `x-veshell.brightness` | brightness percentage | `brightness-6` |
| `x-veshell.battery` | charge percentage | `battery-alert` |

## Battery warnings

`BatteryNotification` (under `power_management/provider/`) watches the system
battery returned by `upowerBatteryDeviceProvider` and raises a warning when it
crosses a threshold **while discharging**:

- **low** at `notifications.batteryLowThreshold` (default `20`), or when UPower
  itself reports `WarningLevel == low`;
- **critical** at `notifications.batteryCriticalThreshold` (default `10`), or
  when UPower reports `critical`/`action`. A critical warning also marks the low
  one as raised, so only the more severe popup appears.

A warning is raised **once per discharge cycle**: the flags are cleared when the
battery charges back up, so a battery hovering at the threshold does not re-warn
on every sample, and the next discharge warns again. A freshly started shell
evaluates the current charge immediately.

UPower's `WarningLevel` is honored alongside the configured percentage so a
device whose percentage is unreliable (or that raises `critical` early) still
warns.

## Settings

`notifications.batteryLowThreshold` and `notifications.batteryCriticalThreshold`
are integers (`0..100`) in `extra/settings/default/settings.json`, exposed by the
**Notifications** settings group. Volume and brightness OSDs are not
configurable.

## Out of scope (future milestone)

Persisting system alerts, an OSD for externally-driven volume changes, action
buttons on system alerts, and per-output volume.
