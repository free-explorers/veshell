# Capture, Recording, And Sharing

Status: proposed implementation reference, reviewed against the current code.
Date: 2026-09-11.
Baseline: Veshell `9563921`, Smithay revision `4cf0b62028039661477d482ec4758b687d8f4392`.

This document supersedes the earlier conversational plans. It specifies a single
architecture, separates required features from later work, and defines checkpoints
for an implementation agent. The status below records which parts are implemented.

## Current Implementation Status

Implemented M3 local-record foundations (2026-09-16, worker + area flow): the
GStreamer worker (`src/embedder/capture/recording.rs`, gstreamer/gstreamer-app
0.24 cargo bindings) encodes RGBA `appsrc` frames through videoconvert →
vp8enc (realtime deadline=1, cpu-used=8, keyframe distance 90) → webmmux →
filesink. PTS derive from the pipeline running time at push
(`do-timestamp=true`), so real elapsed time survives frame drops and idle
scenes; the EOS bus message is polled up to 10 s before the `.part` file is
renamed to the final WebM. File lifecycle: destination paths never overwrite
existing files (collision-suffix search), partial files live beside the
final name during the recording, and failures keep the `.part` file
recoverable in the failure report. The handoff is bounded twice: at most 8
frames travel from the loop to the worker (`SyncSender` try-push) and the
appsrc byte level caps about two frames before the worker starts dropping
(spec 6: slow consumers drop frames, not desktop responsiveness). Missing
plugins are an actionable startup error, and screenshots/sharing keep
working. The worker runs on its own thread and reports exactly one
`RecordingEvent` (Completed/Failed) per session through a calloop channel
into the loop.

The recording flow reuses M1's area selection: Shift+Print begins an
area-recording selection (plain Print stays a screenshot), sharing the same
frozen-snapshot capture session. On release the overlay is dismissed and
recording starts — the first frame is the frozen overlay-free snapshot
frame; further frames are pumped up to the fixed 30 FPS budget by the
compositor loop, each an output snapshot cropped with the same
`compose_desktop_area` used for screenshots, at the pixel geometry captured
at start. Fixed-geometry policy: an output move (space geometry mismatch),
removal, or a scale change stops the recording with the reason logged; the
worker still finalizes and publishes the completed file. Print or Escape
stops a running recording ("user stop"); the finalize is asynchronous
(EOS → rename) and the final path/failure surfaces through
"Recording saved"/failure logs on the loop. Worker tests run the real
pipeline (16×16, 5 frames, assert the EBML/WebM header) plus the collision
search.

Still open in M3 (runtime validation + user-facing UI): the trusted overlay
indicator with elapsed time and a click-Stop is not rendered yet (Stop works
through Print/Escape and layout changes only); encoder-backpressure
compositor-responsiveness testing on real hardware; static-scene duration
correctness verified against the produced file; nested-X11 runs.

First real-machine validation and fixes (2026-09-16, `veshell.log` + file
evidence): Shift+Print selection started a recording (1494×1021) that ran 11
seconds with `dropped=0`, but Stop reported "never finished after the stop"
and the published file was a 418-byte header with zero frames. GST_DEBUG on
the reproduced test showed two composite defects: `do-timestamp` was
stamping pushed buffers before the pipeline clock existed (buffer-provided
before PLAYING warning), which libvpx then rejected with
`Failed to encode frame: invalid parameter` mid-run; and the worker only
read the bus after Stop, so that error sat unread while the frame loop kept
pushing — EOS could never complete. Fixes, all pinned by worker tests
(114 total): (1) PTS are stamped by the worker from its monotonic start
clock (spec's monotonic-derived requirement), no `do-timestamp`; odd
(1494×1021) and even (1494×1020) real-size geometries both now encode
payload — odd height was never the defect, the failing PTS was. (2) The
frame loop drains the bus and reports any mid-run GStreamer error as a
prompt Failed event; a queue that never drains after 120 dropped frames
fails too ("encoder consumed nothing"). (3) The pump is damage-coupled like
the M2.4 sharing path: one copy per presented Flutter frame at the 30 FPS
budget plus a 2 Hz idle heartbeat timer replaces the unconditional 33 ms
snapshot loop that made the desktop stutter. (4) Frames that no longer
compose to the fixed geometry stop the recording immediately with a
reason (no more feeding a doomed pipeline), and the destination `.webm` is
claimed atomically (`create_new`) so two sessions starting at once cannot
fight over the same pair of files.

Release validation (2026-09-16, real machine): a long (24 s) recording
surfaced the start-anchored EOS window (deadline = session start + window),
so Stop skipped the playout wait outright and the recording stayed
unpublished; with the window opened at the Stop, the WebM is published
correctly and plays for the real duration — the static-scene duration check
passed on the same machine. The "video is 0 bytes" artifacts were the
destination placeholder claim left behind on failure paths; failures now
delete the empty claim (only ever while it is still 0 bytes) and keep the
`.part` file. The desktop stutter during recording traced to the validation
tooling itself (debug-profile compositor plus `WAYLAND_DEBUG=server`
tracing): in release the damage-coupled pump runs smooth, matching the M2.4
sharing experience.

Indicator iteration (2026-09-16, user-validated in release): the trusted
overlay now renders the recorded rectangle's outline plus a dimmed desktop
outside it (the same scrim the selection uses), with a pill-shaped
translucent chip inside the rectangle's bottom-right holding a circular red
dot and the elapsed mm:ss left-beside-right-aligned. The counter is real
Roboto text: it resolves the font family the Flutter engine resolves through
fontconfig (`fc-match Roboto`) and rasterizes it CPU-side into a
premultiplied BGRA buffer pushed by the same `MemoryRenderBuffer` path the
native cursor uses — the element list is front-to-back, so the text element
is pushed first with the chip, outline, and scrim piled beneath. Keyboard
down/up pairing: a selection that swallows the release of a key whose press
already reached Flutter under the frozen desktop now synthesizes the
matching keyup, fixing the stuck-modifier state that disabled the shell
hotkeys for the rest of the session. Stop is Print only (click and Escape
ignored; the layout-change stop remains a safety stop). Backpressure has an
automated worker-side probe: an unpaced 60-frame burst on the real-size
geometry must saturate the bounded handoff, drop frames, keep encoding, and
end in a completed, playable file ("saturating_burst_drops_under_backpressure_and_stays_playable").

Implemented native area screenshot slice (2026-09-15, fully native, no Flutter
involvement):

- The `Print` keysym handled in `handle_embedder_hotkeys` (Rust) starts a
  screenshot session and freezes the desktop at hotkey-press time: Flutter and
  Wayland clients receive no input while the session runs, and Flutter framing
  stores presented during the session are dropped instead of replacing the
  frame the user saw at hotkey time (`VeshellView::hold_backing_store`).
- The selection is native: a Smithay pointer grab feeds `input_handling` drag
  tracking, and the DRM/X11 render paths draw a scrim, a selection outline, and
  a native crosshair (`get_capture_overlay_elements`) instead of the real
  cursor. The drag is clamped to the output under the pointer at hotkey time.
- The frozen frame is rendered into capture-owned storage at hotkey time: the
  snapshot contains the Flutter backing store and the game-mode surfaces of that
  single output. On primary-button release, the selection is cropped from the
  snapshot and encoded as a single PNG at that output's scale. The real cursor
  is not part of the captured image.
- The readback is encoded as PNG in the XDG Pictures directory, falling back to
  `~/Pictures` when that directory is unavailable. The same PNG is offered as
  `image/png` on the Wayland and XWayland clipboards.
- Escape or any non-primary button cancels the session. Output layout changes
  cancel it too. There is no Flutter channel or UI left in the local screenshot
  path: `prepare_screenshot`/`take_screenshot` platform channels and the shell
  area selector were removed.

This is not recording, portal capture, MetaWindow capture, or Screen capture. It
synchronously reads back the hotkey-time screenshot and hands capture-owned
pixel data to a background PNG encoding worker, so it is a correctness vertical
slice only. The GPU work stays on the calloop thread; encoding and file I/O run
off the loop and complete on a calloop channel that also publishes the clipboards.

Implemented capture-owned snapshot buffers (2026-09-15, M1 item): the desktop
snapshot is rendered into capture-owned CPU storage once at hotkey time, before
the session starts, from an output-scoped render (frozen Flutter backing store
plus that output's game-mode surfaces, no cursor). Selection completion composes
and crops the selection from the snapshot pixels only; nothing reads a Flutter
swapchain slot or dmabuf after session start, so a recycled or resized
`last_rendered_slot` buffer can no longer corrupt a capture. Snapshot failures
abort the session at hotkey time instead of failing at selection release.

Runtime validation performed on DRM (2026-09-15): a seat session recorded seven
consecutive area captures. The compositor log shows `Entering screenshot capture
mode` followed by `Screenshot saved` for every attempt, with no cancellation and
no snapshot/delivery failures; the produced PNG files exist in the user's
Pictures directory with matching timestamps. Validation was readback-focused:
game-mode multi-monitor behavior is intentionally excluded from this evidence
because the normal render path still selects game-mode windows globally. M1
then remains open pending nested-X11 runtime validation and the game-mode output
routing audit, which is deferred to a dedicated review session.

Implemented M1 foundations:

- Nonblocking screenshot delivery (2026-09-15): PNG encoding and file I/O run on
  a worker thread; the worker writes to a `.part` file beside the destination
  and renames after success. The Wayland and XWayland clipboards are advertised
  only on the event loop once PNG bytes exist, served lazily from capture-owned
  `Arc` bytes.
- Physical output location updates remap `Space`, refresh its output bookkeeping,
  and advance an in-process output-layout revision.
- M2.2 consent picker (2026-09-15): Start defers its portal reply; the
  backend mints an unguessable consent token, opens the trusted picker
  through the platform channel (`screen_cast_consent`), and a Rust-side
  revalidation runs when the decision returns. Approval holds the reply
  while the PipeWire producer negotiates the stream; cancellation reports
  code 1 and closes the session. Picker dismissal is bound to the token
  and every close path (Request.Close, Session.Close, frontend loss)
  revokes an open flow.
- M2.4 validation and damage tuning (2026-09-16): close-path races are now
  pinned by ledger tests. Session.Close, manual close, and frontend loss all
  complete a pending Start reply cancelled (previously a Starting session's
  reply could leak until shutdown on any close source other than the
  approval flow); the second close of the same session is a no-op and
  queues no signal; approval with the stale token after the close attaches
  to nothing; approval on a session that died resolves cancelled on the
  spot, so no node may be published for a consent that granted nothing and
  the picker does not survive its session. The playback kill switch
  (`ConsentResolution::DeadEnd`/`NotMatched`) prevents delivery start on
  any unresolved authorization. Frame delivery became damage-coupled: a
  presented backing store on a session's source output (the authoritative
  damage signal for this compositor) copies once per output per present
  and delivers up to the 30 FPS budget per session (`last_frame`
  timestamps); sessions sharing one output share one capture. A 2 Hz idle
  fallback timer keeps a static desktop with no Flutter presents
  refreshing consumers, and stops itself when the session closes
  (pipewire.rs keeps the PipeWire budget of spec 7). Runtime validation
  with a real consumer through the system frontend remains the open exit
  condition for M2; it is a user-assisted DRM run (Chrome/OBS attach,
  stop paths, consumer disconnect/reconnect observations recorded in this
  document). First real-machine run (2026-09-16): picker and
  authorization reached the approval click, which aborted the
  compositor — `start_stream` had zero-initialized a
  `StreamListener<()>` placeholder, invalid for its non-null inner
  pointer. The placeholder is gone (an `Option` listener stores exactly
  once and `take`s on teardown, registration still completing before
  `connect`); no other zeroed-initialization remains in the capture
  stack. Node-publication correction (2026-09-16, same first-machine
  session): approval reached the producer but the Start reply never
  completed — every attempt stalled at a format-less `Paused`, five
  Chrome retries in a row. An isolated pipeline run
  (`videotestsrc ! BGRx ! pipewiresink` on the same daemon) reproduced
  the mechanism from the other side with `pw-stream: error (-32) no
  target node available`: on this PipeWire neither a consumer nor a
  target means no format fixation — and Start gated on fixate while the
  consumer gated on Start (a deadlock by construction). The producer now
  publishes `NodeReady` as soon as the stream is accepted into the graph
  (`Connecting`, Paused as fallback), mutter's ordering; the fixate
  happens when the daemon links the consumer (`param_changed` fires
  then). This is what specification section 7 ("never wait for a
  consuming application to stream") actually mandates; the earlier
  fixate-gated ReplyLink was that same wait misread as caution. The
  delivery path was already tolerant of pre-fixate frames (dropped until
  `ready_size`). D-Bus reply correction (2026-09-16, directly
  after): Start completed through NodeReady and the compositor aborted
  again at reply construction — `stream_reply` appended bare values
  into a variant-signature `Dict` (`SignatureMismatch (ii, v)`), so the
  first real reply never reached the frontend. The reply builder now
  wraps every `a{sv}` value in `Variant` explicitly, joins the dict
  field through `append_field` (`add_field` re-wraps an existing Value
  into a Variant — a second silent signature inversion found by the
  regression test), and all reply-construction unwraps are graceful
  failures that fall through the ordinary failure/closing path instead
  of aborting. NodeReady repeats (Connecting and Paused) also update
  node state idempotently instead of re-emitting the indicator event.
  Buffer-allocation correction (2026-09-16, same session subject): the
  fixate completed and the consumer linked, but stream buffer allocation
  failed (`alloc buffers: Invalid argument`). The MemPtr Buffers pod
  lacked `size` and `stride`, so the adapter had nothing to allocate
  against, and the `add_buffer` block did not carry the mapped pointer
  (`data.data`) that a `MemPtr` spa_data entry must have. The producer
  now declares size/stride in the Buffers pod (buffer count as a 2..16
  range, reference style) and installs each producer-owned memfd with
  its mapped pointer filled in. Transport-type correction (2026-09-16,
  PIPEWIRE_DEBUG=4 negotiation trace): Chrome's stream demands MemFd
  only (`dataType Flags: Int 4`), so a MemPtr-only offer intersected
  with an empty set — every link reported
  `error alloc buffers: Invalid argument` from `pw_buffers_negotiate`.
  The producer now offers `Flags { MemFd, MemPtr }` (memfd default, the
  fix_datatype convention) and drops `ALLOC_BUFFERS` in favour of
  `MAP_BUFFERS`: the pw daemon allocates MemFd buffers with the declared
  geometry and maps them into this process, so `add_buffer` only records
  the pw-provided mapped pointer and `queue_frame` copies into it. The
  compositor-self memfd machinery is removed.
- M2.3 PipeWire producer (2026-09-16): `pipewire-rs` 0.10 with
  `libpipewire-0.3` 1.6 delivers one BGRx stream per consented session
  (`src/embedder/capture/pipewire.rs`). The PipeWire main loop FD is a
  level-triggered calloop source (Niri's integration pattern, no
  blocking dispatch). Shared memory backed by pw-negotiated MemFd
  buffers (with MAP_BUFFERS client mapping) backs the
  buffers; the producer publishes a `Video/Source` node only after
  approval, Start completes once the node identity exists (spec 7: never
  waiting for the consumer), and the Start result carries
  `streams: [(node, a{sv})]` with logical position, size, and the
  MONITOR source type. Frame delivery initially copies full frames on a
  calloop timer capped at 30 FPS through the M1 snapshot path; damage
  tuning is tracked as follow-up work. PipeWire failure closes the
  affected session, revokes the indicator, and never restores old
  authorization. The persistent trusted indicator (`screen_cast_active`
  / `screen_cast_stopped` platform events) names the shared target with
  the shell Stop action threading `screen_cast_stop` into the close
  path everywhere (user Stop, Session.Close, frontend loss, core
  failure). Frame delivery timing moved to the M2.4 damage coupling
  below; the initial full-frame timer copy only stood until validation.
  Channel order correction (2026-09-16, first shared session): the
  stream reached a live consumer with red/blue-swapped colours — the
  producer declared `BGRx` while the capture readback's Abgr8888 frame
  bytes arrive R,G,B,A (the same bytes M1 screenshots encode as RGBA
  PNGs); the offer is now `RGBA`, matching the compositor readback
  without a channel permute. System reset observation (2026-09-16,
  unrelated to compositor code): the machine hard-reset mid-share
  (`x86/amd: Previous system reset reason [0x00010800]: system reset
  pin BP_SYS_RST_L was tripped`) — no kernel oops, no compositor
  coredump, the journal simply stops; CoreCtrl's amdgpu Overdrive was
  active in that session (kernel warns "Overdrive is enabled"). The
  streaming load under an OC board claim is a suspect to rule out
  before attributing the reset to the producer.
- M2.1 portal backend state machine (2026-09-15): the ScreenCast backend owns
  its name on the real session bus only in the seat session (`RUNS_PORTAL_
  BACKEND`); nested and non-session runs stay silent. Every bridged call is
  authenticated against the live unique owner of
  `org.freedesktop.portal.Desktop` (queried from the bus driver at startup;
  an absent frontend rejects everything). The session lifecycle runs
  Created -> Configured -> Choosing -> Starting -> Active -> Closed on a plain
  ledger with an idempotent close: Session.Close / Request.Close invalidate
  late replies, a frontend owner loss closes every session and pending
  request, and no cancelled session may resurrect. Start cancels safely
  (response code 1) until the consent milestone exists - there is no consent
  to betray yet. Session/Request objects are served on a dedicated object
  bridge thread (compositor code stays off async and signals `Closed()`
  before unexporting). Frontend-owner binding correction (2026-09-16): the
  startup `get_name_owner` seed is best effort — on a fresh login the
  backend can start before the frontend claims its name, and frontend
  restarts change the unique name mid-run, so both leave every call
  rejected with the old binding. The backend now subscribes to the bus
  driver's NameOwnerChanged for `org.freedesktop.portal.Desktop` and
  bridges each event (`None` loss, `Some` rebind) onto the compositor loop
  channel as its own call kind; the ledger stays loop-side, owner change
  closes old sessions, and the new owner authorizes immediately. The
  dead-code gap this closes surfaced on the live machine: two consecutive
  frontend restarts left every ScreenCast call rejected while auth state
  was frozen at a pre-restart unique name.
- Packaging (2026-09-15): `extra/assets/veshell.portal` declares
  `DBusName=org.freedesktop.impl.portal.desktop.veshell` plus the ScreenCast
  interface only; `veshell-portals.conf` selects Veshell for ScreenCast while
  preserving unrelated GTK/GNOME selections; the Makefile, RPM and DEB
  metadata install and uninstall the descriptor together with the selection
  file. Install-path correction (2026-09-16): the descriptor goes to
  `xdg-desktop-portal/portals/` (the only directory xdg-desktop-portal
  scans for backend descriptors); a descriptor directly in
  `xdg-desktop-portal/` is invisible to the frontend and ScreenCast
  selection silently falls back to the desktop's default backend. Descriptor
  header correction (2026-09-16): the keyfile group must be lowercase
  `[portal]` (versions installed with `[Portal]` fail to load —
  "Key file does not have group portal" — and ScreenCast resolution again
  falls back); both traps are silent, the daemon only logs them at
  frontend startup.
- M2.0 portal groundwork (2026-09-15): `zbus` 5 dependency recorded in
  `docs/dependencies.md`; `src/embedder/portal/mod.rs` implements the
  ScreenCast backend v4 contract skeleton (`CreateSession`/`SelectSources`/`Start`
  signatures, Request/Session objects, response codes 0/1/2, MONITOR-only
  `AvailableSourceTypes`), constraint parsing with defaults and strict
  unknown-bit rejection, and frontend-owner authorization. Every backend call
  is bridged onto a calloop channel; replies are completed from the loop
  thread. An isolated session-bus harness (`portal/harness.rs`) runs a private
  `dbus-daemon` plus a fake frontend   the call round trip, and the VIRTUAL-only rejection end to end.
- M2.1 harness coverage (2026-09-15): the harness additionally drives the REAL
  ledger through `apply_portal_call` while the fake frontend exercises
  CreateSession (Session object `version` property = 2), SelectSources
  constraint storage, and its VIRTUAL-only rejection. A second bus connection
  without the frontend name gets response code 2 and creates nothing.
- Flutter backing stores have a per-view generation. The exact generation presented
  in a Flutter layer is retained until presentation or collection, rather than
  promoting whichever buffer was acquired most recently.

These foundations compile and pass the existing test suite; DRM and nested-X11
runtime validation remains required.

## 1. Goals And Scope

User requirements:

- Take screenshots of any rectangular area of the visible desktop.
- Record any rectangular area of the visible desktop.
- Share exactly these kinds of sources: Output and MetaWindow. Sharing an
  existing Veshell virtual Screen was dropped from the product scope; see
  section 13.
- Work with Google Chrome and OBS through their standard Linux portal/PipeWire
  capture paths, including sandboxed installations where supported.
- Keep the implementation small and tailored to Veshell, without introducing
  superseded capture protocols or desktop compatibility layers.

Defaults chosen by this specification, not additional user requirements:

- Local area selection can cross output boundaries, including mixed scales and
  negative output coordinates. An area means a rectangle, not a freehand mask.
- Veshell Screen sharing is not offered: a Screen is never substituted for an
  Output or MetaWindow, and no capture view renders one. See section 13.
- Screenshots are PNG. Initial recordings are silent SDR WebM/VP8 at up to 30 FPS.
- Local capture can snap selection to output, Screen, or window bounds, but the
  resulting area still means visible desktop pixels. It does not gain the
  isolation semantics of sharing a source.
- Sharing has one chosen source per session; several independent sessions may
  coexist within resource limits. Audio, remote input, pause/resume, remembered
  consent, HDR, and live target switching are later features.

## 2. Architecture Decision

Implement the Veshell portal backend and a PipeWire producer in the existing Rust
process. Reuse the existing Flutter shell for consent, selection, and controls.
Continue using the system `xdg-desktop-portal` frontend.

```text
Chrome / OBS
    | org.freedesktop.portal.ScreenCast
    v
system xdg-desktop-portal frontend
    | org.freedesktop.impl.portal.ScreenCast
    v
Veshell Rust portal backend <----> Flutter consent/source picker
    |
    v
authorized capture session -> source rendering -> PipeWire producer
                                                    |
                       frontend-restricted remote -> application

Flutter area selector -> same source-rendering helpers -> PNG worker
                                                      -> recording worker
```

The frame buffers do not pass through JSON or D-Bus. D-Bus and Flutter platform
channels carry control messages only.

Decisions:

- Do not implement `org.gnome.Mutter.ScreenCast` or GNOME Shell screenshot APIs.
  Niri uses those to reuse GNOME's backend and picker. Veshell needs its own picker
  and Screen semantics, so that extra compatibility layer is unnecessary.
- Do not add `wlr-screencopy`, export-DMABUF protocols, or X11 root-window capture.
  Native Wayland Chrome/OBS compatibility does not require them.
- Do not implement `ext-image-capture-source-v1` / `ext-image-copy-capture-v1` in
  this feature. They are modern staging protocols and Smithay's pinned revision
  has handlers, but an internal capture service needs no extra Wayland IPC hop.
  Add them later only for a concrete external capture-client requirement, with
  an explicit authorization design.
- Do not create a separate portal executable/process, generic capture plugin
  framework, public Rust library, or custom Wayland Screen-source extension now.
- Implement a few concrete rendering/delivery functions and session structs.
  A universal `CaptureFrameSink` trait hierarchy is not required.
- PipeWire means connecting as a producer client to the user's existing daemon,
  not implementing a daemon or replacing the user's audio/session manager.

### Corrections To Earlier Plans

- Portal compatibility is the application boundary; it does not dictate the
  compositor's private capture protocol.
- An existing Veshell Screen was never portal `VIRTUAL`, which requests extending
  the desktop with a new virtual monitor; the distinction is moot now that
  Screen sharing is dropped.
- A desktop rectangle is not necessarily contained in one source. Modeling every
  local area as `{ source, rectangle }` would omit cross-output capture.
- A monitor crop is not safe isolated Screen or MetaWindow sharing.
- COSMIC advertises SHM and DMA-BUF capabilities at runtime; its code does not
  establish a historical "SHM first" implementation sequence.
- COSMIC's `RenderElement::capture_framebuffer` hook is not itself a screencast
  interface. Do not copy that hook as a supposed universal capture solution.
- Direct PipeWire integration need not introduce another rendering thread: Niri
  integrates its PipeWire loop FD into calloop.

## 3. Current Code And Constraints

Paths below are relative to the repository root. Read their current contents
before implementation; line numbers and APIs may change.

| Area | Files | Consequence |
| --- | --- | --- |
| Output composition | `src/embedder/backend/render/mod.rs` | Cursor, game-mode surfaces, and Flutter texture are separate render elements. |
| Display backends | `src/embedder/backend/{drm_backend,x11_client}.rs` | Capture must work on DRM and nested X11; Winit is not currently enabled. |
| State and renderer | `src/embedder/state.rs`, `src/embedder/backend/mod.rs` | Reuse calloop and existing GLES access; do not import COSMIC's multi-GPU architecture wholesale. |
| Flutter buffers | `src/embedder/flutter_engine/{view,compositor}.rs` | One swapchain per output-backed view; no Screen-specific backing store. |
| External textures | `src/embedder/texture_swap_chain.rs`, `src/embedder/flutter_engine/{mod,callbacks}.rs` | Audit texture retention/release before adding a second Flutter consumer. |
| Screen state/layout | `src/shell/lib/screen/model/screen.serializable.dart`, `src/shell/lib/screen/widget/screen.dart` | Screen has an ID, workspace list, selected workspace, and label; not an output or framebuffer. |
| Monitor layout | `src/shell/lib/monitor/widget/monitor.dart` | Split-screen bounds are measured Flutter layout, not just configuration percentages. |
| Window identities | `src/embedder/meta_window_state/{mod,meta_window,meta_popup}.rs` | Use MetaWindow identity; persistent tiles may not have a live window. |
| Window presentation | `src/shell/lib/meta_window/widget/meta_surface.dart`, `src/shell/lib/window/widget/window.dart` | Widgets currently change activation, geometry, and output association. Duplicating them is not render-only. |
| Platform control | `src/embedder/flutter_engine/platform_channel_callbacks/` | Follow existing Flutter-to-Rust channel patterns. |
| Portal/session setup | `extra/assets/veshell-portals.conf`, `extra/assets/veshell.service.in`, `extra/assets/veshell-session` | Explicit backend selection, bus ownership, and startup/activation work are required. |

Mandatory rendering audit findings to address where capture depends on them:

- The normal output render paths select all game-mode windows, not just the
  correct output. The local screenshot path filters by `MetaWindow.current_output`,
  but normal rendering still needs the same correction before claiming multi-output
  capture parity. Never append a global list to isolated capture.
- `get_surface_elements()` includes subsurfaces, not independent popup roots.
  Rust tracks MetaPopups separately; map iteration is not a stacking order.
- Flutter's present callback keeps the existing `gl.Finish()` barrier and promotes
  the exact backing-store generation referenced by the presented layer. Keep that
  barrier until a separately verified synchronization replacement exists.
- A `last_rendered_slot`/DMABUF reference alone must not be assumed to prevent
  reuse for the entire duration of asynchronous encoding or streaming.

Do not use unrelated code cleanup or framework upgrades to hide these issues.

## 4. Source And Session Model

Use the existing ID types where possible. The following is conceptual Rust, not
drop-in code or a mandate to introduce all of these names:

```rust
enum ShareTarget {
    Output(OutputIdentity),
    MetaWindow(MetaWindowId),
    // Screen(ScreenId) was dropped with Veshell Screen sharing (section 13).
}

enum CaptureTarget {
    DesktopArea(Rectangle<f64, Logical>),
    Source(ShareTarget),
}

enum CursorMode { Hidden, Embedded }
```

Sharing entry points accept `ShareTarget`, not `CaptureTarget`. A portal caller
cannot inject an arbitrary region or an unapproved ID. Local actions can use both
internally, but the required area-selection workflow uses `DesktopArea`.

Each session records target identity/lifetime, operation, permission state,
requested pixel size/FPS/cursor mode, layout/source revision, monotonic timestamps,
pending work, and delivery-specific resources. IDs are not permissions.

Use lifetime validation as well as display names. A disconnected output replaced
by another output with the same connector name is not automatic authorization to
share the replacement. Screen IDs are existing persistent string IDs; MetaWindow
IDs must resolve to the same live window, not a new window with the same title.

Define an idempotent close path used by every cancellation/failure source.
Never substitute the active window, first monitor, or current workspace on error.

## 5. Rendering Contract

### 5.1 Visible Desktop Areas

Selection coordinates are logical coordinates within the physical output where
selection starts. Clamp them to that output; do not treat Flutter physical pixels
or MetaWindow geometry as global logical positions.

Algorithm:

1. Validate finite coordinates, positive dimensions, and checked allocation sizes.
2. Require the rectangle to remain within the starting physical output. Reject a
   selection crossing a physical output boundary.
3. Use that output's scale at selection time. Set pixel size to
   `ceil(width * scale), ceil(height * scale)`.
4. Render the output scene and crop the selected rectangle. Apply output
   transforms and the backend's Flutter texture orientation.
5. Use completed output scene inputs, including game-mode content. Composite the
   cursor once in capture coordinates, clipped to the area, if requested.
6. Deliver a completed, capture-owned frame.

For a screenshot, capture the latest completed frame at hotkey time: the
selection session freezes the desktop before the user starts dragging, so the
capture happens on release against the frozen backing store. Because the session
withholds input and late Flutter presentations, no overlay-free handshake or
revision correlation is needed. Cancel if output layout changes during the
session.

For recording, dismiss the selector and wait for completed overlay-free frames
from participating views before starting. An arbitrary sleep or Flutter
`endOfFrame` alone is not proof of GPU presentation. Correlate a layout/overlay
revision with a completed embedder frame; verify this handshake in milestone 1.
Carry that revision with the actual completed backing-store identity, not in a
separate "latest revision" variable. Wait asynchronously: calloop must remain
able to service Flutter's buffer requests while awaiting a completed frame.

Stop area recording on output topology, position, scale, transform, or mode
changes affecting its layout. Retain the finalized recording and explain why it
stopped. This avoids silently recording a newly rearranged desktop.

### 5.2 Output Sharing

The source is the complete selected output, including ordinary shell UI and
windows currently visible on it. It intentionally follows changes on that output.
Render the scene into a capture target; do not read only Flutter's texture or a
DRM primary scanout plane. Hardware cursor/overlay planes must not disappear.

Default pixel size is the output's oriented physical size. Handle mode/scale
changes by format renegotiation on the existing stream, or close with a clear
error if renegotiation fails. Never announce success with old-size buffers.

### 5.3 MetaWindow Sharing

Render independently of desktop occlusion and position:

- Include the selected window's client surface, subsurfaces, and explicitly owned
  popup roots. Exclude unrelated windows, shell panels, and Veshell decorations.
- Normalize coordinates to the selected client geometry. Clip popups to that
  viewport for the initial release, avoiding popup-driven stream resizing.
- Child toplevel dialogs are separate MetaWindows and are not automatically
  included. Same application ID/PID is insufficient ownership evidence.
- Preserve stable popup stacking. Verify nested xdg popup offsets and XWayland
  override-redirect ownership; omit a popup if ownership cannot be established.
- Use an opaque black background for the initial SDR stream. Preserve client
  alpha only while compositing, then flatten the result.
- Continue while occluded; close on window destruction/unmapping. Do not resize,
  focus, activate, or move the real client merely to satisfy the capture target.
- Scale or resize the output stream as needed without changing client geometry.

### 5.4 Veshell Screen Sharing (withdrawn)

Sharing an existing Veshell virtual Screen as an isolated source is dropped from
the roadmap (2026-09-17). The product shares Outputs and MetaWindows only; a
Screen is never substituted for either, and no render-only capture view is built.
The former design is not retained as a fallback. Do not reintroduce it without a
new product decision; section 13 records the dropped scope.

### 5.5 Cursor And Color

Baseline supports hidden and embedded cursors. Reuse the existing cursor renderer
for shape, animation, hotspots, and scaling. On isolated sources include a cursor
only when it actually belongs to that source and has a valid coordinate mapping.
Do not overlay the global pointer over an unrelated shared window.

Use an explicitly negotiated 8-bit SDR format initially. Check FourCC/SPA channel
order, stride, origin, alpha, and color conversion; similarly named RGBA/BGRA
formats are not necessarily memory-equivalent. Test red/blue bars and alpha edges.
PNG is sRGB RGBA; streaming/recording is opaque SDR. HDR/10-bit inputs must be
handled under a verified SDR conversion policy or rejected, not mislabeled as SDR.

## 6. Buffer Ownership And Scheduling

Use capture-owned storage, separate from Flutter/output swapchains. A baseline
readback path is acceptable; zero-copy is an optimization, not a privacy shortcut.

Required ownership progression:

```text
available -> rendering -> GPU complete -> delivered -> consumer released -> available
```

- Keep source resources alive until the GPU finishes reading them. Keep capture
  resources alive until both GPU work and consumer use are finished.
- Never lend Flutter's mutable backing store directly to an encoder or PipeWire
  consumer. A duplicated FD does not establish exclusive buffer ownership.
- Do not render from PipeWire real-time callbacks or access GLES from worker
  threads. Keep compositor/PipeWire state on calloop; use messages for work.
- Reuse a small bounded buffer pool (initially three per active continuous capture)
  and at most one outstanding render request per session. Enforce a total memory
  budget with checked arithmetic and explicit allocation errors.
- Slow consumers drop frames, not desktop responsiveness. Never accumulate an
  unbounded queue of pixel data or block calloop on an encoder.
- Use monotonic frame timestamps and sequence numbers. Dropped frames retain real
  elapsed time; do not speed up recorded video by renumbering timestamps.
- Cap initial continuous capture at 30 FPS. Do not busy-loop on an unchanged
  desktop. Send an initial full frame; schedule on damage and consumer demand.
  Recording also needs timed repeat frames or equivalent duration handling so a
  static scene and the final interval remain correctly represented.
- Damage is per capture/session, not simply the display's buffer age. Start with
  full-frame copies if needed; optimize only after ownership/timing tests pass.
- On resize, retire old-generation buffers safely. Never write beyond negotiated
  sizes or reuse a buffer from an old generation.

Readback can cause a bounded GPU wait in the first implementation. Measure it and
report it honestly. PNG encoding, file I/O, and video encoding must be off calloop.
Do not remove current GL completion barriers in the name of nonblocking capture
without implementing and testing replacement fences/resource retention.

## 7. PipeWire Producer

Use the Rust `pipewire` bindings compatible with supported system libraries.
Initialize lazily. Register the PipeWire loop FD with calloop and dispatch without
blocking, following Niri's pattern rather than copying its entire module.

Baseline:

- Publish one video producer stream for each consented sharing session.
- Negotiate one tested SDR packed format using shared-memory/memfd buffers first.
  Implement the actual SPA buffer contract; do not assume `wl_shm` buffers and
  PipeWire buffers are interchangeable.
- No client sees a producer before approval. A published node contains only that
  source, never a chooser preview or another session's frame.
- Report Start success once the producer has a valid published node identity.
  Do not wait for a consuming application to stream: it needs Start's result to
  connect, so waiting would deadlock startup.
- Negotiate FPS/size and obey dequeue/queue lifetime rules. Avoid holding a buffer
  when no render is scheduled. Cleanly handle consumer pause and disconnection.
- On PipeWire failure, close affected sessions and remove event sources/resources.
  A later user request may reconnect; never silently restore old authorization.

Add DMA-BUF as a subsequent optimization of this same producer. Negotiate the
intersection of renderer/allocator/consumer formats and modifiers. Bind/render
only supported buffers, preserve plane offsets/strides, and wait on GPU completion
before submission. Retain the memory path for actual interoperability needs, not
as a second independent capture implementation.

Do not assume Niri renders into buffers allocated by PipeWire: its producer also
allocates/exports backing DMA-BUFs. Choose and document buffer-allocation ownership
explicitly when implementing Veshell's negotiation.

## 8. Portal Contract

### 8.1 Identity And Interface Boundary

Veshell owns `org.freedesktop.impl.portal.desktop.veshell` on the session bus and
exports backend interfaces at `/org/freedesktop/portal/desktop`.

It does NOT own `org.freedesktop.portal.Desktop`, replace the frontend, or export
the application-facing methods as its backend API.

Initial ScreenCast backend version: 4. Advertise `AvailableSourceTypes = 3`
(MONITOR | WINDOW) only once both corresponding implementations work, and
`AvailableCursorModes = 3` (Hidden | Embedded). Persistence is transient
only (amended 2026-09-17 for the Chromium 105+ stream-restoration flow,
which enumerates through a first consented portal session and then starts
the real capture in a second one): an approval may answer
`persist_mode = 1` with an unguessable restore token wrapped in the
impl-facing `restore_data (suv)` blob (`("veshell", 1, token)`; the
frontend turns it into the client's opaque `restore_token` string); a
later flow whose SelectSources carries that blob back skips the prompt
surface, but every restored use still runs the full Rust-side decision
path (live frontend owner, live source identity, requested kinds — see
8.3). Permanent (PermissionStore)
persistence is not claimed: a `persist_mode = 2` request is answered
transiently, and the token's authority dies with the frontend owner, the
compositor process, and the source it names. Persisting by omission is
not allowed: a Start result without a granted token answers
`persist_mode = 0` explicitly. Version 4 is a bounded initial contract, not an
excuse to introduce obsolete compositor APIs. Upgrade to version 6 with serial
metadata once that contract has been tested; retain its required node-ID tuple.

Use the official backend XML/docs to implement exact signatures:

| Backend method | Input | Output |
| --- | --- | --- |
| `CreateSession` | `handle:o, session_handle:o, app_id:s, options:a{sv}` | `response:u, results:a{sv}` |
| `SelectSources` | `handle:o, session_handle:o, app_id:s, options:a{sv}` | `response:u, results:a{sv}` |
| `Start` | `handle:o, session_handle:o, app_id:s, parent_window:s, options:a{sv}` | `response:u, results:a{sv}` |

`CreateSession` returns an empty results dictionary on success. `SelectSources`
stores/validates constraints, not user consent. `Start` opens the trusted picker
and returns `streams: a(ua{sv})` after approval and node publication.

There is NO backend `OpenPipeWireRemote` method. The frontend creates the
restricted PipeWire connection and passes its FD to the application. Veshell must
not hand an ordinary unrestricted PipeWire connection to Chrome/OBS.

Backend methods return their response pair after asynchronous work. They do not
emit frontend `org.freedesktop.portal.Request.Response` signals. Export backend
`Request.Close()` at supplied request paths and backend `Session.Close()`, its
`version` property, and `Closed()` signal at supplied session paths. Backend
`Session.Closed()` has no arguments. Verify these against upstream XML.

Response codes: 0 success, 1 user cancellation, 2 other failure. Return appropriate
D-Bus errors for unauthorized/malformed calls rather than panicking.

### 8.2 Picker And Type Mapping

| Veshell source | Portal category/type | Picker behavior |
| --- | --- | --- |
| Output | MONITOR = 1 | Output name and icon. |
| MetaWindow | WINDOW = 2 | Application/title and icon. |

The baseline picker is text/icon-only. Do not implement live or cached pixel
previews of unselected targets: when an Output is already shared, Flutter could
bake an otherwise hidden window's preview into that stream. Add pixel previews
only after capture-transparent trusted UI composition is proven. Output sharing
can show ordinary text controls just like other visible shell UI; it must not
gain hidden targets' pixels through the chooser. Test concurrent requests.

Veshell Screen sharing is dropped (section 13): the picker has no Screen group,
no Screen-to-MONITOR mapping is claimed, and no private source-type bit or
`VIRTUAL = 4` reinterpretation is added.

Filter the picker by requested `types`. A WINDOW-only request cannot choose an
Output. Default missing types to MONITOR and cursor to Hidden. A
VIRTUAL-only request has no supported sources and must fail normally. Validate
supported bit intersections/options according to the portal contract.

Choose one source even if `multiple=true` (the contract allows at least one).
Support independent sessions, not multiple streams per session initially.
Do not use a global reply channel whose result can be consumed by another request.

Return `source_type` and meaningful logical size metadata. Output position is
global logical position; do not invent physical monitor coordinates. Node IDs
are not persistent source IDs.

The picker names the requesting application, not a supposedly authenticated web
origin. Chrome's own UI is responsible for website/tab permissions. Browser tab
capture is outside this compositor feature.

### 8.3 Authorization And Lifecycle

```text
Created -> Configured -> Choosing -> Starting -> Active -> Closed
                                               |
                                Active can be paused by the consumer
```

Every nonclosed state can close. Track PipeWire transport state separately from
portal authorization so a paused consumer does not trigger a second consent flow.

- Authenticate backend calls against the current unique bus owner of
  `org.freedesktop.portal.Desktop`; the caller-supplied app ID is not credentials.
  Authenticate Request/Session methods as well as the main interface.
- Bind each session to that frontend instance and its app identity. A frontend
  name-owner loss/replacement closes all its sessions and pending requests.
- D-Bus handlers use async per-request replies through calloop. Never lock or
  borrow mutable renderer state across a user interaction or `.await`.
- Bind picker replies to unguessable request tokens/revisions and validate source
  type, source lifetime, and authorization in Rust again after selection.
- Closing a request during the picker or PipeWire startup invalidates late
  replies. No cancelled session may publish a node or restart later.
- A persistent trusted shell indicator names the shared target and provides Stop.
  It must appear before delivery begins and remain accessible across workspaces.
- Revoke on user Stop, session closure, target disappearance, frontend loss,
  PipeWire failure, shell loss, session lock, or compositor session deactivation.
  Clear cached previews and capture buffers on revocation as appropriate.
- Revocation destroys/stops the producer, not just its D-Bus objects. Previously
  delivered pixels cannot be recalled, but no newly rendered frame may be sent.
- No raw public capture endpoint may bypass consent. Native Flutter actions are
  trusted shell actions, not D-Bus calls authorized by app ID or PID alone.

### 8.3.1 Transient Stream Restoration

Chromium's enumerating-then-capturing double session is what other
compositors solve with remembered consent; Veshell supports the transient
slice only (see the 8.1 persistence amendment):

- The restore handshake lives at the impl boundary, not in the client's
  vocabulary. The frontend translates the client's opaque
  `restore_token (s)` into the backend-facing `restore_data (suv)` blob
  and back, so the backend never sees the token itself. Veshell emits
  `("veshell", 1, token)` in the Start results and accepts it in
  SelectSources options; a blob with another vendor or a newer private
  version is ignored and degrades to the prompt (the user may have
  switched desktops). Chromium/GNOME/COSMIC all exchange this `(suv)`
  shape — a bare `restore_token` string in the backend results registers
  nothing and prompts twice.
- An approval may mint one unguessable token, stored Rust-side in
  lru-bounded memory bound to `(approving frontend owner, approved source
  identity)`. Start answers `persist_mode = 1` plus the encoded blob; no
  grant means `persist_mode = 0` explicitly.
- A presented blob never authorizes by itself: its unwrapped token must
  match the live frontend owner, its source kind must fit the request's
  `types`, and the approval decision revalidates the source's live
  identity (the same registry check an explicit picker click runs). A
  dead window, a replaced output, or a foreign frontend yields the
  ordinary prompt instead, never a stale stream.
- Authorities that kill grants: frontend owner loss/replacement,
  compositor process exit, and the source's own destruction or unmap
  (validated per use). Frontend restarts clear the grant map eagerly.
- Revoked live authorization does not revoke the token, because the
  point of the grant is a future consent for the still-alive source; a
  removed source's token resolves to nothing.
- True longer-term persistence (PermissionStore, surviving compositor
  restarts) is out of scope and stays deferred (section 13).

Runtime-validated against Brave (2026-09-17): first flow prompts, the
follow-up flow restores silently, and a new gesture prompts again.

The frontend's restricted remote protects portal clients according to PipeWire's
access policy. Do not claim this prevents every unrestricted same-user host
process from accessing PipeWire. Verify the deployed daemon/session-manager policy.

### 8.4 Screenshot Backend

Add `org.freedesktop.impl.portal.Screenshot` version 2 when native screenshot
capture is ready. Implement both `Screenshot` and `PickColor` as specified by the
backend contract, including request cancellation and trusted user interaction.
PickColor is a one-pixel sample from the same frozen desktop snapshot.

Return screenshot `uri` as a valid file URI. Use a private file in a private
Veshell capture directory, keep it available after the reply, and clean portal
temporary files at session end. The frontend handles sandbox/document export.
Do not let supplied titles/path strings select arbitrary write locations.

`interactive=false` is not permission to capture silently. Initially prompt for
all external screenshot/color requests. Never interpret `permission_store_checked`
as a positive grant by itself. Defer Screenshot v3 and its separate target enum.

## 9. Local Screenshot And Recording Delivery

PNG encoding and disk I/O run on a worker using completed CPU bytes. For native
screenshots offer Save and Copy Image; implement image/png clipboard ownership in
the compositor/selection path, not text containing a file path. Keep clipboard
bytes valid for asynchronous reads and test Wayland and XWayland consumers.

For recording, use a GStreamer worker with Rust bindings and an `appsrc` pipeline
fed by the same capture frames. Baseline pipeline: raw SDR frames -> color
conversion -> VP8 encoder -> WebM muxer -> file. Do not add a second PipeWire
consumer or an external screencopy subprocess solely for native recording.

- Use explicit caps, monotonic-derived PTS/duration, bounded appsrc/worker queues,
  and nonblocking handoff from calloop. Drop stale frames under load.
- Detect required plugins at runtime; an absent encoder disables recording with
  an actionable error without breaking screenshots or sharing.
- Support one local recording at a time initially. Show elapsed time and Stop in
  trusted shell UI. No recording starts before explicit user action.
- Write to a temporary partial file beside the destination. On Stop send EOS,
  finish muxing asynchronously, and rename only after success. Do not overwrite
  existing files silently. Preserve/report recoverable partial files on failure.
- Handle disk-full, encoder errors, cancellation and shutdown without hanging the
  compositor. A static scene must have the correct final duration.
- Use XDG Pictures/Videos directories for native saves, with a user-visible path
  choice and collision-safe filenames. Do not hardcode English home subfolders.

GStreamer is the selected baseline, not one of several interchangeable frameworks
the coding agent should implement. Codec/audio/hardware-encoding choices can be
revisited separately if the product needs them.

## 10. Modules And Installation

Suggested placement, introducing files only as their milestone needs them:

| Path | Responsibility |
| --- | --- |
| `src/embedder/capture/mod.rs` | Targets, validated sessions, scheduling, close path. |
| `src/embedder/capture/render.rs` | Desktop composition/crop and isolated source rendering. |
| `src/embedder/capture/pipewire.rs` | Producer negotiation, buffers, calloop integration. |
| `src/embedder/capture/recording.rs` | GStreamer worker and file lifecycle. |
| `src/embedder/portal/mod.rs` | zbus backend, authentication, Request/Session objects. |
| `src/shell/lib/capture/` | Picker/selector, registry, render-only Screen root, controls. |

Follow the existing Riverpod/Freezed/platform-channel conventions. Add new
dependencies (`png`, `pipewire`, `zbus`, GStreamer bindings) only when needed and
record system packages/minimum versions in `docs/dependencies.md`. Do not copy
generated FFI from references or upgrade Smithay/Flutter without a demonstrated
missing API. Keep dependency features/build policy consistent with the project.

Install a `veshell.portal` descriptor in the portal descriptor directory, declaring
only implemented interfaces and `DBusName=org.freedesktop.impl.portal.desktop.veshell`.
Explicitly select Veshell for ScreenCast and Screenshot in
`extra/assets/veshell-portals.conf`; preserve unrelated GNOME/GTK selections.
Update Makefile, RPM and DEB assets together, including uninstall paths.

In-process backend activation is a release gate, not an assumption:

- In the real session, acquire the backend name after its handlers/control path
  are ready and before session readiness causes portal activation.
- D-Bus activation must resolve to the already managed session process. Never
  configure `Exec=veshell` to start a second compositor on a capture request.
- Verify a supported activation descriptor/service mapping for the existing
  session unit. If it cannot satisfy the bus/session-manager contract, stop for
  design review of a minimal activation helper; do not silently introduce a
  second capture backend or change the compositor's service type blindly.
- Outside a Veshell session fail clearly rather than launching a graphical
  session. Do not replace GNOME's/another Veshell instance's bus name.
- Nested X11 tests use an isolated D-Bus/PipeWire test environment for portal
  integration. Do not redirect the host desktop's portal as a test shortcut.

The initial production portal activation target is the systemd-managed Veshell
session. The repository also has dinit/direct-launch paths: native screenshots
and recording must remain usable there, but portal support must be labeled
unverified until each launch mode passes name ownership, activation, and shutdown
tests. Do not silently claim the systemd mapping supports all launch modes.

## 11. Milestones For The Implementation Agent

Implement one milestone per reviewable change. Update this document if a verified
API limitation changes a decision. Do not claim the entire feature from an output
screenshot prototype, and do not enable unsupported picker entries.

### M0: Confirm Contracts And Test Harness

Inspect the files in section 3 and the official backend XML. Record the chosen
dependency versions. Establish unit tests for target validation/geometry and an
isolated session-bus harness for portal calls. Investigate in-process D-Bus
activation integration. These spikes gate M2's portal delivery, not M1's native
screenshots or M3's native recording. If a spike fails, record the failure and
request a decision for that branch. The capture-view spike was tied to Veshell
Screen sharing and is dropped with it.

### M1: Native Area Screenshots

Screenshot state: hotkey interception, session freeze, native drag selection
(with scrim, outline, crosshair), single-output scene rendering without the
cursor, PNG delivered to Pictures and to both clipboards. Remaining work: runtime
validation on DRM and nested X11, nonblocking delivery, capture-owned snapshot
buffers for later preview/recording work, and a Flutter feedback surface (toast)
when one is wanted.

Audit game-mode output routing (the normal render path still selects all
game-mode windows, not just the pieces assigned to the output that would claim
multi-output parity).
Tests: multiple Veshell Screens on one output, output-edge clamping, dialogs and
popups, game mode, clipboard delivery, and image orientation/channel order.

Exit: arbitrary-area screenshots work on DRM and nested X11 without PipeWire.

### M2: PipeWire And Output Sharing

Implement in-process backend plumbing, authenticated Request/Session lifecycle,
Flutter consent, indicator/Stop, one memory-buffer producer, and packaging.
Initially advertise MONITOR only. Test Chrome and OBS Output sharing, cancellation
at every state, late approval, owner loss, restricted remote, and buffer pressure.

Exit: real apps share an output through the system frontend, with no GNOME/wlr
capture dependency. Missing PipeWire does not break M1.

### M3: Local Recording

Implement area recording with the GStreamer worker and fixed geometry policy.
Reuse M1's area renderer, not a second capture implementation. Test a long static
scene, movement, frame drops, Stop/EOS, disk-full, output changes and worker errors.

Exit: a completed recording plays for the correct duration and the compositor
remains responsive under encoder backpressure.

### M4: MetaWindow Sharing And Screenshot Portal

Implement isolated client/popup rendering and window lifecycle tests. Advertise
WINDOW only now. Add Screenshot/PickColor backend methods, cancellation and file
accessibility tests. Confirm no unrelated window leaks when sharing an obscured
window or opening an application dialog/menu.

M4 progress (2026-09-17, build validated: 122 tests green; runtime
validation over a real app pending): the Screenshot portal slice is in. The
backend exports `org.freedesktop.impl.portal.Screenshot` version 3 on the
shared `Desktop` object path (`Screenshot`, `PickColor`, `AvailableTargets`
fixed to Screen=1); `veshell.portal` and the preferred-portals selection
advertise the interface. The ledger gained a dedicated screenshot map beside
the capture sessions: a request validates its `request/` handle, exports its
Request object, mints an unguessable consent token, and defers the method
reply to a Flutter-side `screenshot_prompt` dialog (Allow/Deny, screen/color
kind). Approval takes the pixels in Rust through the M1 snapshot pipeline
composed at full output geometry — no selection, no desktop freeze, no
pointer grabs — then encodes PNG on a worker thread; the completed response
carries `uri: file://` into the shared screenshot directory. The response
frame is the pre-prompt desktop (2026-09-17, Gradia runtime feedback): the
pixels are frozen once at request arrival — before the `screenshot_prompt`
dialog renders — and encode from that held frame on approval, so the prompt
dialog never appears in the result and a denial drops the held buffer; the
holds are evicted by reconciliation against the ledger after every portal
call, on frontend loss, and on decisions (runtime check pending for the
zero-overlay file). PickColor samples the pre-prompt frame at the pointer
location recorded with the request, so the color is stable while the dialog
is up, and answers `(ddd)` RGB doubles. Cancellation in
any stage (RequestClose, frontend owner loss, in-flight entry) answers
response 1, dismisses the prompt, and unexports the object; stale tokens and
unavailable targets fail with response 2. Ledger coverage: the prompt opens
and holds the reply, RequestClose completes cancelled and unwinds the
object, and an approval moves the reply into the capture stage.

Window-share slice (2026-09-17, build validated: 128 tests green; runtime
validation pending) — MetaWindow sharing per spec 5.3. Isolated rendering:
`capture_window_pixels` renders the window's own surface tree
(subsurfaces included) at the client's `scale_ratio` — never an output
scale — with owned popups (the `MetaPopup.parent` == meta window id
registry, no pid/title/geometry guessing) composited above in surface-id
stacking order into an opaque-black viewport taken from the client's own
content geometry (its global logical position and pixel size are the
Start result's position/size); a pure `compose_window_pixels` +
`blit_clipped` pair (unit tests: popup clip, negative origins, layer
scales, black background) makes the privacy property testable: nothing
except the handed-in layers can appear, so an obscured window or a
parent opening a separate dialog cannot leak unrelated content. The
portal backend advertises `AvailableSourceTypes = MONITOR | WINDOW`
(spec 8.1's gate: both implemented kinds), the Start gate accepts
either kind, and the picker receives types-tagged sources filtered by the
request's `types` (a WINDOW-only request cannot offer outputs, pinned by a
ledger test that also checks the gate behind parsing). windows groups separately and the picker requires an explicit selection
(no preselected default — approving by a careless click can no longer
approve a screen instead of a window; 2026-09-17 runtime finding: Brave's
own window-flow UX still requests the mixed set). A Start-vs-SelectSources
constraint precedence rule landed the same day: Chromium/OBS call
SelectSources with `types: 3` and then Start with the option keys omitted,
and the parse defaults must not clobber the SelectSources-stored kinds (the
first Brave run lost its windows list exactly there; pinned by ledger
tests for both directions — stored-kinds survival on a key-less Start and
explicit Start options overriding the storage); SelectSources and Start
both log their resolved `requested_types`.
The consent flow
revalidates window sources in Rust: an approved id must resolve to a
live, mapped MetaWindow at approval time and again at delivery start; a
window stream is torn down on window removal (`remove_meta_window`) and
on unmap (`UpdateMapped` false) through the ordinary close path — the
producer stop, ledger close, and indicator all run through the idempotent
close. Window streams carry `source_type = 2` in the Start result.

Runtime correction (2026-09-17, Brave): Chromium 105+ runs the
enumerating-then-capturing double portal flow, and the backend's key-less
Start must keep the SelectSources-stored kinds (pinned by tests; the first
run lost its windows list there) and support transient stream restoration
(spec 8.1/8.3.1 amendment): Start answers `persist_mode = 1` with an
unguessable token bound to the approving frontend owner and source; a
presented token skips the prompt after the same Rust-side validation an
explicit choice runs, and frontend owner changes drop the grants
wholesale. Ledger tests pin the preselected-approval event path, the
owner death, and the Start-result persistence keys.

Third verify pass (2026-09-17, the actual root cause): the first two
placements failed because the handshake is not the client's vocabulary at
all. Veshell is an *impl* backend, and the frontend owns the translation:
it replaces the client's `restore_token (s)` with the stored backend
`restore_data (suv)` blob and mints a fresh client token only when the
backend returns `restore_data` in Start results
(xdg-desktop-portal `src/xdp-session-persistence.c`
`replace_restore_token_with_data` /
`generate_and_save_restore_token`). A bare `restore_token` string in the
backend results (passes one and two) was passed through to the client but
never registered, so the next flow's token was dropped before SelectSources
reached us. Fix: emit and parse `("veshell", 1, token)` `(suv)` blobs, as
GNOME and COSMIC backends do; foreign vendors/newer versions degrade to
the prompt.

Runtime-validated (2026-09-17, Brave): after the fix the first flow of a
gesture prompts, and the follow-up flow reports
`presented_token=true restore_resolved=true` and starts silently; a new
share gesture (no token, fresh grant) prompts again. One consent prompt
per user gesture, transient for the frontend owner's lifetime.

Remaining M4 work: runtime portal-Screenshot validation against a real
sandboxed app, a real app share an obscured window through the system
frontend, and portal-restart behavior checks.

### M5: Existing Screen Sharing (dropped)

Dropped from the roadmap (2026-09-17). No Screen registry, render-only capture
view, view removal, frame scheduling, Screen picker group, or Screen-to-MONITOR
mapping is implemented. The exit target is reduced to the two offered sources:
Output and MetaWindow.

### M6: Performance And Release Validation

Measure baseline frame/readback cost, memory, compositor latency and dropped
frames. Add negotiated DMA-BUF delivery and per-session damage reuse if needed for
the release target. Verify GPU completion and modifier fallback. Test ScreenCast
v6 serial metadata before advertising that version. Complete the matrix below.
Do not declare a CPU-readback prototype a proven high-performance 4K recorder.

## 12. Acceptance Tests

Automate pure state/geometry/protocol tests; keep hardware/application tests as a
repeatable checklist with recorded versions and results. A failed/unrun test is
not a pass. No benchmarks or runtime compatibility have been established yet.

| Test | Required result |
| --- | --- |
| Chrome screen sharing and OBS PipeWire source | Consent appears, target is correct, frames update, Stop ends delivery. |
| Flatpak OBS / sandboxed client | Portal remote and screenshot URI work without broad host capture permission. |
| Requested source-type filtering | WINDOW-only never offers Outputs; VIRTUAL creation is not advertised. |
| Two simultaneous applications | Correct per-request results and independent streams; stopping one cannot redirect/stop the other. |
| Open/cancel another picker during Output sharing | No unselected-source pixel previews leak into the first application's stream. |
| Direct backend call by another bus client | Rejected even if it supplies a trusted-looking app ID/session path. |
| Cancel picker / cancel during stream startup | No late node/recording and no resurrected session. |
| PipeWire / frontend restart | Sessions end safely; new consent is required to restart. |
| Lock / session deactivation / shell loss | Delivery ceases; no lockscreen or other session's new pixels are captured. |
| Output removal and same-name reconnection | Previous authorization is not reused for the replacement. |
| Cross-output selection | Selection is clamped to the starting physical output. |
| Mixed DPI, negative origins, desktop gaps | Outside the initial single-output scope. |
| Overlay removal for recording | No selection rectangle/picker in the first recorded frame. |
| Cursor at boundaries, animated or client cursor | Correct hotspot/shape, single compositing, no cursor on an unrelated isolated source. |
| Occluded MetaWindow / nested popups / XWayland menu | Only selected client and verified owned/clipped popup content. |
| Parent app opens a separate dialog | Dialog is not automatically included as a same-app window. |
| Game-mode window on nonprimary output | Display/output capture agree; isolated capture includes only owned content. |
| Slow/no consumer, resize, repeated start/stop | Bounded memory/FDs/views, no premature buffer reuse, no compositor deadlock. |
| Missing encoder/PipeWire | Clear feature-specific error; unrelated capture and desktop functionality remain usable. |
| Static recording and dropped frames | Correct elapsed duration; EOS produces playable WebM. |
| Disk-full and destination collision | No silent overwrite, no frozen compositor, partial-file status reported. |
| Wayland/XWayland clipboard paste | Receives actual PNG bytes after the screenshot UI closes. |

Run `cargo check` / `cargo test` and targeted formatting for changed Rust code.
Use the project's selected Flutter SDK for analysis, generation and tests in
`src/shell`; do not silently switch to an arbitrary system Flutter. If Flutter
tests are introduced, add the missing appropriate test dependency. Preserve and
report pre-existing failures rather than performing unrelated mass fixes.

## 13. Explicit Deferrals And Review Gates

Do not implement these by guessing:

- Veshell Screen sharing is dropped, not deferred: no Screen registry,
  render-only capture view, Screen picker group, or Screen-to-MONITOR mapping is
  built. Reintroducing it requires a new product decision.
- In-process D-Bus activation: prove in M0; stop for review if it fails.
- Sharing a workspace pinned independently, new virtual outputs,
  region sharing, multiple sources per session, persistent (PermissionStore)
  consent — the transient restore slice is implemented and specified in 8.3.1,
  anything surviving compositor restarts stays out — metadata
  cursor, remote input, audio, HDR, hardware encoding and arbitrary public capture
  clients are outside this initial feature.
- Session lock/deactivation must have a reliable Rust capture-revocation hook
  before release. If the current shell has no trustworthy lock state, integrate
  that state rather than claiming capture is lock-safe based on widget visibility.

Security, cancellation, buffer ownership and source isolation are not deferrable
polish. Do not ship an advertised source until those properties hold.

## 14. References

Reference repositories are design evidence, not code to copy wholesale:

- Niri `dd75865f`: `src/screencasting/pw_utils.rs` (PipeWire/calloop, negotiation,
  GPU completion), `src/screencasting/mod.rs` (source lifecycle),
  `src/dbus/mutter_screen_cast.rs` (a compatibility layer Veshell will not need).
- COSMIC Comp `a5578599`: `src/wayland/handlers/image_copy_capture/` (source/session
  separation, constraints, rendering), `src/wayland/protocols/image_capture_source.rs`
  (Output/Workspace/Toplevel), `src/utils/screenshot.rs` (native readback).
- The separate COSMIC portal backend was not inspected; do not infer its
  PipeWire implementation or workspace-to-portal mapping from cosmic-comp alone.
- [ScreenCast backend](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.ScreenCast.html)
- [ScreenCast frontend](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html)
- [Screenshot backend](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.Screenshot.html)
- [Backend Request](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.Request.html)
- [Backend Session](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.impl.portal.Session.html)
- [PipeWire access boundary](https://flatpak.github.io/xdg-desktop-portal/docs/pipewire.html)
- [Backend installation](https://flatpak.github.io/xdg-desktop-portal/docs/writing-a-new-backend.html)
- [Portal selection](https://flatpak.github.io/xdg-desktop-portal/docs/portals.conf.html)
- [Image capture sources](https://wayland.app/protocols/ext-image-capture-source-v1)

Online documentation evolves. Confirm wire signatures and supported versions
against upstream XML and the deployed frontend before advertising capabilities.
