# Surface pacing

## Description

Client windows are drawn by the shell through Flutter, so the compositor cannot
tell from its own render which of them are on screen. Without that knowledge
every client received a frame callback on every vblank, and a window nothing
displays (a tile on another workspace, a hidden ephemeral window, an occluded
window) kept rendering at the panel's refresh rate.

The shell reports which client surfaces it displays, and the compositor paces
each surface's frame callbacks accordingly. The model follows niri's: visible
surfaces are driven by the refresh, invisible ones get a slow heartbeat so a
client blocked on a callback never stalls completely.

## Split

| Concern | Owner |
| --- | --- |
| Which surfaces are painted on screen, and which only need a low rate | Shell (`SurfaceVisibilityTracker`) |
| Frame callbacks, presentation feedback, held commits, deferred redraws | Compositor (`surface_pacing`) |

## Report

Every place the shell draws a client texture wraps it in a
`SurfaceVisibilityProbe`. After each frame the shell evaluates them with the
same rules the probe uses for `painted`: a surface is visible when one of its
probes is painted by its ancestors, not clipped away entirely and not fully
transparent. A probe under a `SurfaceFrameRateLimit(limited: true)` (a paused
game) reports its surface as limited, painted or not: a paused game on a
workspace that is not shown would otherwise be hidden, and slowing only its
frame callbacks does nothing to a game with vsync off. A surface shown both
ways counts as visible.

The shell sends `surface_visibility` with the `visible` and `limited` surface
ids whenever the result changes. Until the first report the compositor treats
every surface as visible.

## Paces

| Pace | Surfaces | Frame callbacks |
| --- | --- | --- |
| Full | Visible surfaces, popups, windows shared through a screen cast, the active game, and the keyboard or pointer focus | Every vsync tick |
| Limited | Surfaces reported limited: a paused game, shown behind its frost or on a workspace that is not | 15 per second |
| Hidden | Everything else | About once a second |

The order matters: a visible, shared or gaming surface is full first; then a
limited surface stays limited even under the pointer (a paused game takes no
input, and hovering its frosted tile must not lift the limit); then the input
focus is full; anything left is hidden.

A surface that becomes visible gets its next frame callback on the next tick
instead of waiting out its previous interval, so it resumes painting at once.

## Limited surfaces

Frame callbacks alone do not slow a client that ignores them (a game with vsync
off). While a surface is limited:

- each of its commits is held (a blocker), and each paced tick applies only
  the oldest one: a client that queued several frames since the last tick (a
  game with vsync off fills every buffer it has) gets one frame through per
  tick, runs out of free buffers and slows down to the limited rate;
- the shell is told about its new frame only on those ticks, so the frosted
  tile is redrawn at the limited rate too.

On a tick at any other pace, and at once when the surface stops being limited,
all its held commits apply: a held commit never outlives the pace that held
it.

## Presentation feedback

Presentation feedback of a shell-drawn surface is answered with its frame
callbacks: presented on the pacing output when the surface is full or limited,
discarded when it is hidden.

## Invariants

- A surface the shell does not report keeps receiving frame callbacks, at
  least about once a second.
- A limited surface's commits are never held while it receives a callback
  every tick.
- Pacing never applies to an active game: its frame callbacks follow its own
  output's vblank (see [Gaming mode](gaming_mode.md)).

## Trade-offs and open points

- A hidden recorder (OBS) whose graphics thread waits on its own window's frame
  callbacks would slow to about one frame a second; its recording keeps going
  only if it does not depend on them. This needs checking against a hidden OBS
  recording (issue #236).
- Holding a limited surface's commits can delay the first frame after resuming
  by up to one limited interval.
