# TileableWindow

## Description

a TileableWindow is a [Tileable](tileable.md) that represent an application window that persist in the layout even when it's closed.

## Launch lifecycle

A launch runs the application through `AppLaunch` in a tracked
`veshell-launch-<tile-uuid>-*.service` unit. Removing the tile while the launch
has not produced a native window cancels that unit (`systemctl --user stop`,
i.e. SIGTERM to the cgroup); once a window is displayed the tile is no longer
pending and the application exits by closing its window. A launch whose process
is already showing a window under another tile is left running.

While the session is leaving (logout, reboot, shutdown), window-loss and
title-change events are transient: the tile does not persist them, so the last
complete window state survives into the next session. See
[state_manager.md](state_manager.md).

## Resume context

A tile that has no window resumes its saved work when clicked; it is never
started "fresh". Fresh launches remain the launcher's job (overview/app
drawer), and nothing is started automatically at shell startup.

The context lives in `PersistentWindow.resumeContext`, separate from
`properties` (which follows the currently displayed window and is overwritten
by helper surfaces). It stores:

- the saved working directory;
- the captured argv (fallback command line);
- the executable identity;
- the tracked-launch cgroup, used to find sibling tiles;
- terminal shell/working directory (the foreground program replayed by #188);
- the capture time.

### Capture

The context is captured from the launch configuration, refreshed from
`process_info` when a window maps and when its title changes, and polled every
5 seconds while the tile displays a window. Rust reads `/proc/<pid>/cmdline`,
`cwd`, `exe`, and — for terminal windows — the shell descendant and its
foreground job. Capture never blocks a launch; unreadable `/proc` facts simply
leave the previous context in place.

Windows started outside the shell are captured the same way: the displayed
process is the source of truth, not the fact that this shell launched it.

### Relaunch

1. A custom exec remains a shell command; the saved cwd applies.
2. Otherwise the desktop entry's `Exec` is parsed into argv, `%f/%F/%u/%U` are
   filled from saved documents, `%i/%c` are expanded, and non-document
   arguments are appended. Arguments and paths are never interpolated into a
   shell string; `systemd-run` receives them as discrete argv elements.
3. If the desktop entry is gone, the captured argv/executable is used.
4. A saved cwd that is gone falls back to `$HOME` (then the compositor cwd);
   a tile with no captured context keeps the compositor cwd. A missing
   document is dropped, and an unusable command leaves the tile as a
   placeholder. The click is never refused because part of the context is
   stale.

### Sibling tiles

Before a launch, other tiles of the same application group (same desktop-entry
id, or same saved cgroup) are armed with a small waiting penalty. The clicked
tile gets first claim; the matching engine distributes
additional windows from the same launch to the siblings. The application is
launched only once, and arming itself persists nothing.

### Failure, retry and forgetting

A resume that produces no window within ~25 seconds clears the waiting state,
keeps the context and shows Retry / Forget. Retry cancels a still-pending
launch before starting again, so it cannot spawn a duplicate. Forget clears the
tile's resume context and title but keeps the tile, its app id, display mode and
custom exec.

Closing a window does not clear the context. Only Forget or removing the tile
does.

Terminal foreground-program replay, the allowlist and terminal-specific exec
syntax are specified by #188.

## Properties

WindowState state; // placeholder or opened  
List<[Window]()> modalList;  
