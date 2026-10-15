# EphemeralWindow

## Description

an EphemeralWindow is an application window that is meant for a short lived session like a quick search or accessing system settings.

It is runtime-only: `WindowManager` persists only `PersistentWindowId`, so
ephemeral windows do not survive a shell restart. It is created by an
[EphemeralApplicationLauncher](ephemeral_application_launcher.md) and rendered
by `EphemeralWindowWidget`.

## Lifecycle

- **Created** — `WindowManager.createEphemeralWindowForDesktopEntry(entry, screenId)`
  from the overview, which registers the window and its panel tab.
- **Launched** — `EphemeralWindowState.launchSelf()` resolves the desktop entry
  and launches it through `AppLaunch`, tracked to the window's uuid so the
  application's surfaces are attributed back to this window.
- **Waiting** — `metaWindowId` is `null` until a native window is matched. The
  window shows the launch's execution logs (from the launched process' pid) in
  a dark container, with a progress indicator while the process is still
  starting. A launch that never produces a surface — a single-instance app that
  only raises an existing window, or a failed launch — stays readable here
  instead of becoming a blank card.
- **Opened** — once a meta window is attributed, `EphemeralWindowWidget` renders
  it (`WindowWidget`) maximized and hands it the keyboard: focus moves to the
  window's surface node, so keys the client handles (`Enter`, `Space`, `Escape`,
  `Tab`, directions) fall through to it instead of being consumed by the
  overview's search pane. While the surface has not been matched yet, the
  placeholder holds the keyboard for the same reason.
- **Closed** — closing the native window removes the window. Closing while no
  native window is owned (the waiting case above) removes the window directly
  and cancels its pending launch (`systemctl --user stop` on the tracked
  `veshell-launch-<tile-uuid>-*.service` unit), so a launch that never opened a
  window cannot get stuck on screen or linger in the background.

## Properties

List<[Window]()> modalList;
