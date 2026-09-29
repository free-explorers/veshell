# Veshell - Specifications

This is Veshell technical specifications for high level components

## Service boundary

Freedesktop D-Bus services (the xdg-desktop-portal backend, the notifications
server, screensaver inhibition) are owned by the Rust compositor: it claims the
well-known names, serves the interfaces and emits the signals. The Dart shell
owns state and interaction — routing, persistence and UI. Rust forwards accepted
calls over the platform channel and completes the D-Bus reply from the shell's
answer. Each service specification records its exact split.

## Components

- [Display](/specifications/display.md)
  - [Monitor](/specifications/monitor.md)
    - [Screen](/specifications/screen.md)
      - [ScreenPanel](/specifications/screen_panel.md)
      - [Workspace](/specifications/workspace.md)
        - [WorkspacePanel](/specifications/workspace_panel.md)
        - [Tileable](/specifications/tileable.md) ( [PersistentWindow](/specifications/persistent_window.md), [PersistentApplicationLauncher](/specifications/persistent_application_launcher.md) )
      - [Overview](/specifications/overview.md)
        - [EphemeralApplicationLauncher](/specifications/ephemeral_application_launcher.md)
        - [EphemeralWindow](/specifications/ephemeral_window.md)
- [WindowManager](/specifications/window_manager.md)
- [Notification](/specifications/notification.md)
- [MediaPlayer](/specifications/media_player.md)
- [StateManager](/specifications/state_manager.md)
