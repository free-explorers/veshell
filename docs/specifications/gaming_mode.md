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
   mode ÷ fractional scale), then patches `fullscreen`. It does **not**
   activate: the tile stays paused, with the dim and the instructions over the
   game, so entering or navigating to a game tile never grabs the input.
3. Clicking resumes: the dim fades while a fullscreen route zooms the surface
   in.
4. When the route's own transition completes, the shell patches
   `UpdateGameModeActivated(true)`. Activation is tied to the route, not to the
   Hero flight: a skipped transition, a missing source Hero or reduced-motion
   must still grab the compositor.
5. The compositor sets `game_mode_activated` and `meta_window_in_gaming_mode`,
   enters the client at the surface origin, and starts forwarding keyboard,
   pointer motion, buttons and axis to it.
6. `Ctrl+Esc` clears the flag. The compositor replays a release for every key
   the client was still holding (the `Ctrl` of the chord included) before the
   grab is dropped, then the shell pops the route and the dim fades back in.

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

## Performance and latency

Gaming mode exists to take the game off the shell's critical path, in both
directions.

**Rendering.** While `game_mode_activated`, the client's surface is composited
by the DRM backend directly as a render element above the Flutter texture
(`get_frame_elements_from_dmabuf`), not only through the shell's
`MetaSurfaceWidget`. It is presented on each output retrace rather than being
limited to the shell's frame production, so a dropped or late Flutter frame
does not delay the game. Compositing is driven by the KMS vblank.

**Input.** Keyboard, pointer motion, buttons and axis are forwarded straight to
the client by Smithay (`KeyboardHandle::input_forward`, `PointerHandle`) and
never pass through Flutter or the shell widget tree, so shell event handling
cannot add a frame between the device and the game.

**Pacing.** The output is composited every retrace and Flutter's vsync batons
are delivered by a timer (`vsync_tick`), not gated on a page flip: a static
shell, or a static game, cannot stall the render pump.

**Trade-offs and non-goals.**

- The client buffer is still imported into a Flutter external texture and the
  shell still builds the (covered) surface route, so while active the frame is
  effectively produced twice. A follow-up could stop feeding the surface to
  Flutter once the native render owns the output.
- The compositor re-composites the whole output each retrace, including the
  full-screen Flutter texture, even when only the game changed.
- There is no per-app frame pacing, no VRR/adaptive-sync handshake and no
  latency instrumentation; the mode trades power and some duplicated work for
  responsiveness.
- Entering and leaving the mode is not a hot path: it costs a resize configure,
  a route transition and, on leave, synthetic key releases.
