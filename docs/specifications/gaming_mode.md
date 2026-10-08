# Gaming mode

## Description

A per-window display mode in which a client's surface is composited by the Rust
compositor at full output size instead of through the Flutter texture, and
input is forwarded straight to the client. It removes the shell's compositing
and input latency for games while keeping the tile in the layout.

A tile enters gaming mode when its `displayMode` is `game`
([PersistentWindow](persistent_window.md)). It is the only display mode the
compositor does not know about: the shell maps `game` to a `fullscreen` xdg
configure.

## Split

| Concern | Owner |
| --- | --- |
| User intent (`displayMode == game`), tile UI, resume/pause overlay | Shell |
| Surface placement, native rendering, input forwarding, the `Ctrl+Esc` grab release | Compositor |
| "Actively grabbed" flag (`MetaWindow.gameModeActivated`) | Shared, mirrored over the patch channel |

## Lifecycle

1. The shell sets `displayMode = game`.
2. The overlay resizes the window to the monitor's **logical** size (physical
   mode ÷ fractional scale), then patches `fullscreen`, then pushes a
   fullscreen route. The resize must come first: the fullscreen configure has
   to carry the final size, because Chromium latches the size from the
   configure that sets fullscreen.
3. When the route's own transition completes, the shell patches
   `UpdateGameModeActivated(true)`. Activation is tied to the route, not to the
   Hero flight: a skipped transition, a missing source Hero or reduced-motion
   must still grab the compositor.
4. The compositor sets `game_mode_activated` and `meta_window_in_gaming_mode`,
   enters the client at the surface origin, and starts forwarding keyboard,
   pointer motion, buttons and axis to it.
5. `Ctrl+Esc` clears the flag. The compositor replays a release for every key
   the client was still holding (the `Ctrl` of the chord included) before the
   grab is dropped, then the shell pops the route and shows the paused scrim.
6. Clicking the scrim resumes from step 2; the paused state is remembered for
   as long as the tile owns the overlay.

## Invariants

- A game surface renders on exactly one output: the one its tile was placed on
  (`MetaWindow.currentOutput`). Rendering is scoped the same way in the live
  backends and in capture readback.
- `game_mode_activated` and `meta_window_in_gaming_mode` name the same window;
  removing that window clears both.
- Leaving gaming mode never leaves the client believing a key is held, and
  entering it never leaves Flutter believing a key is held.
- The window geometry patched on entry is logical, matching every other
  fullscreen path.
