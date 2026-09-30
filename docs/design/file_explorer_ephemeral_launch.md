# Opening a file's handler as an ephemeral window — design notes

Status: **investigation, not implemented.** Branch `feat/file-explorer`.
This is a scratchpad for a design decision, not a settled contract; the
contract for the explorer itself lives in
[`specifications/file_explorer.md`](../specifications/file_explorer.md).

## Goal

When the user opens a file from the overview's Files pane, the application that
handles the file should appear as an **ephemeral window** in the overview —
short-lived, not placed in a workspace tile — matching how apps launched from
the overview's application search behave.

Today it does the opposite: `xdg-open` starts an untracked process, the
compositor sees a normal new toplevel, and the matching engine turns it into a
persistent workspace tile.

## Current behavior (M2)

- `lib/file_explorer/provider/file_opener.dart` — `FileOpener.openFile` runs
  `xdg-open <path>` (fallback `gio open`), detached.
- `lib/overview/widget/search/search_engine.dart` — on success the overview is
  dismissed via `overviewStateProvider(screenId).notifier.hide()`.
- Result: a normal new toplevel, placed in the focused workspace by the
  matching engine.

## How ephemeral windows work today

- **Model** — `lib/window/model/ephemeral_window.dart`:
  `EphemeralWindow { windowId, properties, screenId, metaWindowId? }`.
  Ephemeral windows are runtime-only: `WindowManager.build` persists only
  `PersistentWindowId` (`lib/window/provider/window_manager/window_manager.dart`).
- **Creation** — `WindowManager.createEphemeralWindowForDesktopEntry(entry, screenId)`.
- **Overview flow** — `OverviewState.startEphemeralApplication(entry)`
  (`lib/overview/provider/overview_state.dart`): creates the window, adds it to
  `Overview.windowList`, focuses it, then calls `launchSelf()`.
- **Launch** — `EphemeralWindowState.launchSelf()`
  (`lib/window/provider/ephemeral_window_state.dart`) calls
  `WindowProviderMixin.launchSelf()` (`lib/window/provider/window_provider.mixin.dart`),
  which resolves the desktop entry from `properties.appId`, builds a
  `LaunchConfig`, and calls
  `appLaunchProvider.launchApplication(config, trackedWindowId: state.windowId)`;
  then `waitForSurface(pid)` arms the "just launched" matching bonus.
- **Tracked launch** — `lib/application/provider/app_launch.dart` runs the
  command under `systemd-run --user … --unit=veshell-launch-<window-uuid>-<suffix>`
  with `/bin/sh -c <command>`. Descendants inherit the cgroup;
  `AppLaunch.windowForPid` maps cgroup → tile uuid, so the app's meta window is
  attributed back to the ephemeral window.
- **Rendering** — `EphemeralWindowWidget`
  (`lib/window/widget/ephemeral_window.dart`) renders `WindowWidget` when
  `metaWindowId != null`; `OverviewContent` shows it.
- **Identity refresh** — `EphemeralWindowState.onMetaWindowDisplayedPropertiesChanged`
  copies the displayed meta window's `WindowProperties` (appId/title/icon) into
  the ephemeral window.

**Key point:** the systemd unit / cgroup is what makes the launched app's
window belong to the ephemeral window. Any launch path that escapes the unit
(D-Bus activation handing off to an already-running instance) loses
attribution, and the window lands in a workspace tile instead.

## Proposed design

Resolve the file's default handler, create an ephemeral window for it, and
launch it **with the file**, tracked to that window.

1. **Resolve the handler** — new provider under `lib/file_explorer/provider/`:
   - MIME: `xdg-mime query filetype <path>` (xdg-utils, same package as the
     `xdg-open` already used; alternative `gio info -a standard::content-type`).
   - Default app id: `xdg-mime query default <mime>`.
   - Entry: existing `localizedDesktopEntryForIdProvider(id)`.
   - Verified on this machine: `xdg-mime query filetype /etc/hosts` → `text/plain`;
     `xdg-mime query default text/plain` → `org.onlyoffice.desktopeditors.desktop`.
2. **Create the ephemeral window** — extend
   `createEphemeralWindowForDesktopEntry` with an optional file, or add
   `createEphemeralWindowForFile(entry, path, screenId)`; add to
   `Overview.windowList` and focus. The handler entry gives the panel button the
   right icon/title immediately.
3. **Launch with the file** — build a `LaunchConfig` from the entry's `Exec`
   with the file substituted, then launch through the tracked path to the
   ephemeral window id.

### Exec field-code handling

The command runs through `/bin/sh -c`, so the path must be shell-quoted.

- `%f` / `%u` (single) and `%F` / `%U` (list) → substitute the file path.
- `%%` → `%`.
- `%i %c %k %d %v %m` → remove.
- If the `Exec` contains no file field code, append the quoted path.
- Quote rule: wrap in single quotes, and turn each `'` into `'\''`.

## Code touch points

| File | Change |
|---|---|
| `lib/window/model/ephemeral_window.dart` | add runtime `DirectoryPath? fileToOpen` |
| `lib/window/provider/ephemeral_window_state.dart` | `launchSelf` branch when `fileToOpen != null` |
| `lib/application/model/launch_config.serializable.dart` | `fromDesktopEntryWithFile` factory |
| `lib/window/provider/window_manager/window_manager.dart` | create ephemeral window for a file |
| `lib/overview/provider/overview_state.dart` | `openFileAsEphemeral(path)` entry point |
| `lib/file_explorer/provider/file_opener.dart` | becomes the no-handler fallback |
| `lib/file_explorer/widget/file_explorer_view.dart` | file tap → new path |

## Alternatives considered

1. **`gtk-launch <desktop-id> <file>` or `gio launch <desktop-file> <file>`**,
   run tracked to the ephemeral window. No `Exec` parsing needed, but D-Bus
   activation can escape the cgroup; also `DesktopEntry` exposes `id` but not
   the desktop file path that `gio launch` needs. (`gtk-launch --help` confirms
   `APPLICATION [URI…]`.)
2. **Placeholder window + `xdg-open <file>` tracked to it**, letting
   `onMetaWindowDisplayedPropertiesChanged` fix the identity. Least code, but
   the panel button shows a placeholder briefly and attribution is weaker.

## Caveats / risks

- **Single-instance app already running**: no new window appears; the ephemeral
  window would sit empty. There is no "no surface arrived" timeout today.
- **No handler resolved**: fall back to today's `xdg-open` (normal window) or
  no-op + log.
- **`LaunchConfig.arguments` is declared but unused** —
  `app_launch.dart` only runs `config.command`, so the file has to be embedded
  in the command string (quoted) unless `arguments` is wired up.
- **Single file only** for now; multi-selection is future scope.
- **Quoting/security**: paths may contain spaces or quotes.
- If the overview is dismissed on open but no window appears (single-instance
  case), the user sees nothing.

## Open questions

- Replace `xdg-open` entirely, or add an explicit *Open in window* action
  alongside it?
- What to show when no handler is resolved?
- Behaviour when the handler is already running (no new surface)?
- Should a future multi-selection open every file in one ephemeral window?
