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
7. A game that closes itself leaves gaming mode through the same exit: the
   window removal deactivates the mode before the window is dropped, so the
   compositor releases the pointer focus it set on entry and the shell pops the
   zoom route exactly as for `Ctrl+Esc`.

## Invariants

- A game surface renders on exactly one output: the one its tile was placed on
  (`MetaWindow.currentOutput`). Rendering is scoped the same way in the live
  backends and in capture readback.
- `game_mode_activated` and `meta_window_in_gaming_mode` name the same window;
  removing that window clears both.
- A paused game tile never holds the keyboard: switching the tile to `game`
  keeps the shell's own focus scope focused (`PersistentWindow`), so global
  hotkeys still resolve and navigation works. Only `game_mode_activated` routes
  key events to the client.
- While activated the compositor keeps the pointer and keyboard focus it set
  on entry: shell widget churn (the surface is swapped for a placeholder, the
  route covers the tile) must not clear them, or the game stops receiving
  motion, buttons or keys.
- While activated the pointer is confined to the game's output: crossing to
  another monitor would re-show the cursor there and hand the other desktop a
  stray pointer.
- While activated the client's cursor image is authoritative: a game cursor
  surface is drawn even though the shell stops reporting a surface under the
  pointer, and a client that hides its cursor hides it — the shell's own cursor
  (from Flutter `MouseRegion`s) never overrides it.
- Deactivation clears the compositor-set pointer focus, so a paused game stops
  receiving motion even before the shell re-establishes a focus. A game that
  closes itself deactivates before its window is removed, so the freed surface
  is never left as the pointer focus and Flutter gets its pointer events back.
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
does not delay the game.

Rendering is **on demand**: a Flutter present, a client commit, pointer input
or the idle fade schedules a composite, and the output is presented on the next
retrace. The vsync timer only delivers Flutter's vsync batons and the Wayland
frame callbacks; it no longer renders every retrace.

While active, the game surface is also **kept out of Flutter**: its external
texture frame is not signalled and the shell draws a placeholder instead of
`MetaSurfaceWidget`. A game frame therefore does not schedule a Flutter frame,
so there is no duplicate rasterization and no full-output damage from the shell
— only the game's own damaged region is repainted.

**Input.** Keyboard, pointer motion, buttons and axis are forwarded straight to
the client by Smithay (`KeyboardHandle::input_forward`, `PointerHandle`) and
never pass through Flutter or the shell widget tree, so shell event handling
cannot add a frame between the device and the game.

**Pacing and adaptive sync.** Flutter's vsync batons and the Wayland surface
frame callbacks are delivered from the pacing output's page-flip vblank, so
while the shell is presenting they stay aligned with the panel. A page flip only
happens when something is damaged, though, and a static shell has no vblank to
deliver from, so a fallback timer at the pacing refresh covers that case: it
ticks only once a whole refresh passed without a vblank (a static scene, or a
dropped frame), so a running scene is never double-ticked. Both take one cheap
wake-up per refresh and back off while the output is blanked or the seat
inactive.

The game is not paced by that timer. On-demand rendering presents its frame when
the client commits, and while a window is in gaming mode the DRM backend enables
adaptive sync (VRR) on that output when the connector supports it without a
modeset (`Backend::set_output_vrr`). The panel then refreshes when the game
presents instead of at a fixed cadence, and holds the last frame while the game
is idle. A connector that needs a modeset, or does not support VRR, is left at
the fixed cadence, so entering or leaving the mode never flickers the output.

**Instrumentation.** Every presented frame that carried a game surface logs, at
`debug`, the time between queueing and presentation and the interval since the
previous gaming frame (the achieved pace). That measures the compositor's own
contribution to latency and makes pacing regressions visible without a profiler.

**Trade-offs and non-goals.**

- The client buffer is still imported into a Flutter external texture even while
  active, but it is neither signalled nor drawn, so the cost is the import, not
  a second rasterization.
- Adaptive sync is toggled, but the compositor does not implement its own
  frame-pacing loop (for example a synthetic cadence for a 30 fps game); the
  client's own presentation and the Wayland frame callbacks drive it.
- Entering and leaving the mode is not a hot path: it costs a resize configure,
  a route transition and, on leave, synthetic key releases.
