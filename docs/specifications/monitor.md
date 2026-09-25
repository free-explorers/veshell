# Monitor

## Description

a Monitor represent a physical display device used to render Veshell

## Properties

int x;  
int y;  
int width;  
int height;  
List<[Screen](screen.md)> screenList; // List of all the screens displayed in the current Monitor  

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
