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
   activate: the tile stays paused, with the game frosted (the same
   `FrostedSurface` the overview and the dialog area use) and the instructions
   over it, so entering or navigating to a game tile never grabs the input.
3. Clicking resumes: the frost lifts while a fullscreen route zooms the surface
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
   grab is dropped, then the shell pops the route and the frost fades back in.
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
retrace. Requests are coalesced: however many arrive before the event loop goes
idle (a 1000 Hz mouse, a commit), a node gets one composite. The vsync timer
only delivers Flutter's vsync batons and the Wayland frame callbacks, plus a
composite for an animated theme cursor; it does not render every retrace.

On demand only holds if an unchanged scene composites to **no damage**. The
Flutter frame is drawn as one element with a stable id per view, whose commit
moves only when Flutter presents a new frame. A fresh element id on every
composite would make the whole output look new each time: every render would
flip, the output would flip continuously at its highest refresh, and a game
frame would wait behind the shell's own flip.

A composite asked for while the output's previous flip is still pending is not
dropped: that output's own vblank renders it, so a game frame committed during
a flip is presented on the next refresh.

Game surfaces are **scanout candidates**: when the game's buffer can be put on
a plane (it covers the output in a format the plane accepts), the DRM
compositor shows it without a GPU composite. Otherwise it falls back to
rendering.

While active, the game surface is also **kept out of Flutter**: its external
texture frame is not signalled and the shell draws a placeholder instead of
`MetaSurfaceWidget`. A game frame therefore does not schedule a Flutter frame,
so there is no duplicate rasterization and no full-output damage from the shell
— only the game's own damaged region is repainted.

**The shell stops rendering** while activated games cover every output: the
compositor holds Flutter's vsync batons, so Flutter produces no frame at all
(commits of background windows would otherwise keep it rasterizing and
compositing behind the game). Activation only happens once the zoom route has
completed, and the lock screen clears the game surfaces, so the shell is never
paused while something it draws is visible. Leaving gaming mode, a game that
closes, or a lock makes the next vsync tick release the held baton. With a
second monitor showing the shell, Flutter keeps rendering for it.

**Scanout.** Game surfaces receive per-surface dmabuf feedback with a scanout
tranche: the formats their output's planes accept (and that the renderer can
also sample). A client honouring it allocates buffers the display can show
directly, which lets the scanout-candidate game element go on a plane. While a
game owns the output, the primary plane accepts a buffer of any format (games
render 8-bit while the swapchain prefers 10-bit, and a same-format rule would
always refuse them); the configuration is test-committed first, and a buffer
the plane rejects is composited. Leaving
gaming mode sends the render feedback back. Outputs of a secondary GPU get no
scanout tranche.

**Buffer readiness.** A commit whose dmabuf the client's GPU is still
rendering is held until that rendering finished (a dmabuf blocker on every
surface); until then the surface keeps showing its previous buffer. Composited
or scanned out early, the frame would wait on the client's fence, and an
uncapped game always has its newest buffer in flight, so the flip would miss
its vblank.

**GPU priority.** The compositor's EGL context is created at high priority
(`EGL_IMG_context_priority`): a GPU-bound game must not delay the composite,
and with it the flip waiting on its fence, by a refresh. A driver that does not
grant it falls back to the default; the level obtained is logged when the
context is created.

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

The game is not paced by that timer. Its frame callbacks are sent from the
vblank of **its own output** (the one its tile is on), once the frame it
committed was presented, and never from the pacing CRTC: a game on a monitor
whose refresh or phase differs from the pacing one would otherwise render
against the wrong panel and stutter. When its output went a whole refresh
without a flip (a commit with no damage presents nothing), the fallback timer
sends them instead. On-demand rendering presents its frame when the client
commits, and while a window is in gaming mode the DRM backend enables
adaptive sync (VRR) on that output when the connector supports it without a
modeset (`Backend::set_output_vrr`). The panel then refreshes when the game
presents instead of at a fixed cadence, and holds the last frame while the game
is idle. A connector that needs a modeset, or does not support VRR, is left at
the fixed cadence, so entering or leaving the mode never flickers the output.

**Paused games.** A paused game shows only through its frost, so it is paced
down to 15 frames per second: its frame callbacks, its commits and the shell's
redraws of its tile (see [Surface pacing](surface_pacing.md)). Resuming lifts
the limit at once.

**Presentation time.** The DRM backend exposes `wp_presentation`, so clients
pace vsync'd frames on real presentation timestamps (Xwayland's Present, Mesa's
Vulkan WSI, DXVK) instead of a fallback timer. A game surface's feedback is
answered at the vblank of the flip that carried its content, with the hardware
timestamp and sequence (`Vsync`, `HwClock`, `HwCompletion`, plus `ZeroCopy`
when it was scanned out) and its output's refresh, reported as variable while
adaptive sync is on. Shell-drawn surfaces are answered on the vsync tick, like
their frame callbacks. Every feedback is answered: a game commit that
presented nothing is answered by the fallback timer, and the flip in flight of
a blanked or disconnected output is discarded.

**Instrumentation.** Every presented frame that carried a game surface logs, at
`debug`, the time between queueing and presentation and the interval since the
previous gaming frame (the achieved pace), and whether the frame used direct
scanout (`primary_scanout`, `overlays`). Pausing and resuming the shell is
logged at `info`. That measures the compositor's own
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
