# Screen

## Description

a Screen represent a portion of a Monitor where we want to render Veshell. Monitor usually contain a single Screen but for ultra-wide monitor it could be usefull to be able to split it in several Screen.

## Properties

int x;  
int y;  
int width;  
int height;  
List<[Workspace](workspace.md)> workspaceList;

## Workspace list

A screen's `workspaceList` always ends with an empty workspace: that trailing
slot is how a new workspace is created. Opening a window in the last workspace
appends a fresh one automatically, and the screen drops the redundant trailing
slot when the workspace before it becomes empty while the user is elsewhere.

The invariant also holds across a restart. A persisted list can end with a
non-empty workspace (for example when the previous session removed the
redundant blank); restore normalizes it before the screen builds by appending a
fresh empty workspace, so the last slot is usable immediately instead of only
after the next workspace change.

## Focused screen

`focusedScreenProvider` holds the screen that currently owns focus, or `null`
while no screen exists. It is reconciled against `screenManager`'s live screen
set:

- A still-valid focused screen is preserved when other screens are created or
  removed.
- If the focused screen is deleted, `ScreenManager.removeScreen` moves focus to
  the first remaining screen before deleting it; if none remain the value is
  `null`.
- The value never points at a deleted screen and never throws.

Readers treat `null` as "nothing focused": a new window is left unplaced rather
than routed into a missing screen, unresolved notifications are not surfaced,
and `focusedMonitor` falls back to the first connected monitor.

### Keyboard and pointer

The focused screen is the one that holds the keyboard, and **a click moves
it**, never the pointer's motion alone:

- The compositor gives a monitor the keyboard on the first button press over
  it (`focus_view_under_pointer`), before Flutter receives the press. Moving
  the pointer onto another monitor changes nothing for the keyboard. When the
  monitor holding the keyboard is unplugged, the monitor under the pointer (or
  the first remaining one) takes it.
- Within a monitor split into several screens, a press on a screen focuses
  it.
- When a screen takes the keyboard back, its selected workspace's selected
  tile takes it too (`WorkspaceFocusable`), and a press on the selected tile
  re-takes it as well: Flutter's focus must never stop at the workspace while
  the compositor gives the window the keyboard, or the keys a client expects
  (Tab, arrows, Space, Enter) drive the shell's focus and controls instead of
  reaching the window.

What surfaces without being asked for follows the pointer instead:
`placementScreenProvider` is the screen the pointer last entered (falling back
to the focused screen). It places new windows and unresolved notifications,
the system notifications (volume, brightness), trusted prompts and the lock
screen's password field (through `focusedMonitor`), and decides which screen
touchpad swipes act on. A prompt that takes the keyboard moves the keyboard's
monitor to it.

The shell's hotkeys follow the pointer too. A Super chord bound to a screen
action (navigation, moving or closing a tile) and the Super tap that toggles
the overview act on the screen under the pointer: when the keyboard is on
another screen, that screen takes the keyboard first, as a click on it would,
and the action runs there once it has. System hotkeys (volume, brightness,
media, keyboard layout, lock, the key display) act wherever the pointer is
and move nothing. Plain-key bindings (Enter for `navigation.activate`) belong
to the focused widget and never follow the pointer. The shortcut manager
(`VeshellShortcutManager`) implements this.
