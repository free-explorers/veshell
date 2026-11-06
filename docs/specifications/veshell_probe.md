# Veshell probe

## Description

`veshell-probe` lets a developer **see, measure, drive and verify** a running
Veshell: screenshots of the shell or of one widget, the
on-screen geometry of a widget, deterministic frame sequences of an animation,
synthetic input, snapshots of the shell's state, and one-call verification of a
change.

It exists because unit tests cannot tell that a card is translucent, that a
launcher is duplicated or not painted, or that an animation lands off its
target: until now, each of those needed a screen recording and a frame-by-frame
look during the tiled launcher work; each is one probe call.

It is a command line tool, also served as JSON-RPC tools over stdio for editor
integrations, with images returned inline.

It is a development tool: none of it is part of a release build.

## What already exists

The probe builds on facts of the current tree, verified at the time of writing:

- **Dart VM service.** The embedder starts the engine with
  `--vm-service-host=127.0.0.1 --vm-service-port=<12345 + wayland socket number>`
  and `--disable-service-auth-codes`, and exports the URL as
  `VESHELL_VM_SERVICE_URL`; with `VESHELL_VSCODE_DEBUG` set it also writes
  `.vscode/vmService.json` (`src/embedder/flutter_engine/mod.rs`). Plain HTTP
  `GET` calls on it reach the `ext.flutter.*` service extensions of a debug
  build, notably:
  - `ext.flutter.inspector.getRootWidgetTree`: the widget tree, with source
    locations;
  - `ext.flutter.inspector.screenshot`: a PNG of one widget;
  - `ext.flutter.inspector.getLayoutExplorerNode`: size and constraints;
  - `ext.flutter.debugDumpRenderTree`: every render box, with its offset;
  - `ext.flutter.timeDilation`: the animation clock's speed.
- **Nested backend.** The embedder has a `winit` backend
  (`src/embedder/backend/winit.rs`): a Veshell instance can run in a window of
  the developer's session instead of on the hardware.
- **Compositor capture.** `src/embedder/capture/` records the composited
  output (shared memory, PipeWire, WebM recording), application windows
  included.
- **Launch traces.** `PlatformEventRecorder` dumps the platform events of a
  launch for debugging (`src/shell/lib/platform/provider/platform_event_recorder.dart`).
- **State views.** `src/shell/lib/dev_tools/` shows the shell's state, windows
  and surfaces in the overview when dev tools are enabled.
- **Animation speed.** The `theme.animationSpeed` setting drives
  `timeDilation` for the whole shell.

Flutter's own tooling servers do not help as they are: they find
applications through the Dart Tooling Daemon, where an application launched by
`flutter run` or an IDE registers, and Veshell's own embedder does not.

## Architecture

Three layers, each usable without the ones above it.

### 1. Shell extensions: `ext.veshell.*` (Dart)

Service extensions registered by the shell **in debug builds only**
(`kDebugMode`), giving the shell's meaning rather than raw widgets:

| Extension | Returns |
| --- | --- |
| `ext.veshell.views` | The views (one per monitor): id, logical size, device pixel ratio. |
| `ext.veshell.find` | The widgets matching a type, a key (a `ValueKey`'s value) or a text, each with its global rect, the part ancestor clips leave in view (`visibleRect`), the product of its ancestors' opacities, whether its ancestors paint it at all (`painted`), and whether it is visible. |
| `ext.veshell.act` | A tap (on a point, or on a found widget's visible center), a key chord delivered through the focus system as a real key press is (Enter in a text field is its input action), or text typed into the focused field. |
| `ext.veshell.capture` | A PNG of the layer tree a view painted on its last frame (what is on screen, not a fresh paint of a widget), cropped to a region, at a pixel ratio. |
| `ext.veshell.state` | JSON snapshots of the shell's main stores: screens, workspaces, persistent windows. |
| `ext.veshell.settled` | Whether the shell is idle: no frame pending, no animation running. Screenshots compared with references wait for it. |
| `ext.veshell.info` | The embedder's control socket (`VESHELL_PROBE_SOCKET`). |
| `ext.veshell.clock` | Freezes the animation clock, steps it by an exact duration, resumes it. Frames keep running while frozen; only the time animations see stands still. A frozen clock resumes on its own after 30 s without a call, so a probe that died cannot leave the shell frozen. |

`painted` follows each ancestor's own `paintsChild`, plus what that misses: a
viewport only paints the slivers it shows, and a multi-box sliver only the
children whose slot overlaps its paint extent. A box laid out but skipped (a
sliver page shown sliding over a visible slot while its own slot is out of
view) has a rect on screen but is not painted. A sliver that paints every
child it builds implements `ProbePaintsEveryChild` (none on `main` yet; the
tiled launcher's page sliver is the intended first one: without the marker,
its off-slot pages read as not painted). `capture` shows what was
painted too, unlike `ext.flutter.inspector`'s screenshot, which paints the
widget afresh.

Widgets the probe needs to target get stable `Key`s (`ValueKey('launcher')`,
the existing `LaunchMorph.flying*Key`s); `find` accepts them by name.

### 2. Embedder controls (Rust)

A control socket, compiled in debug builds only (`src/embedder/probe.rs`):
`$XDG_RUNTIME_DIR/veshell-probe-<wayland socket>.sock`, private to the user,
JSON lines, exported to the shell as `VESHELL_PROBE_SOCKET`. A thread serves it
and hands each request to the event loop.

- **`outputs`**: the outputs, their logical geometry and scale (the views map
  to them through their monitor name).
- **`capture_output`**: the composited output, application windows included,
  written as a PNG to the path the request gives (the capture module's own
  full-output path).
- **`inject`**: pointer motion, buttons and wheel through the compositor's own
  input handlers, from a probe `InputBackend` whose events implement Smithay's
  traits, and keys through the keyboard handler: focus, Super chords, Flutter
  and Wayland clients see them as real input.

### 3. Harness: `veshell-probe` (command line and tool server)

A Dart command line package under `extra/probe/`, built with the pinned SDK
(`.flutter_sdk`), using the first-party `vm_service` client for layer 1 and the
control socket for layer 2. `veshell-probe serve` serves the same commands as
JSON-RPC tools over stdio.

Dart is chosen over a script because `vm_service` is the maintained, typed
client of the VM service and the harness can share model types and key names
with the shell.

## Instances

The probe works against one of two instances:

- **Isolated (the default).** `veshell-probe start` runs a nested Veshell
  (winit backend), by default inside a headless Weston (GL renderer, kiosk
  shell) of a fixed size (`--size`, 1280x800): off the developer's screen, and
  the same size everywhere, which reference frames need (`--windowed` nests it
  in the developer's session instead). It gets:
  - a temporary `VESHELL_CONFIG_DIR` (settings, persistence);
  - temporary XDG directories (videos, data, cache) and a temporary `HOME`,
    so nothing reaches the user's;
  - a private session bus of its own (`dbus-daemon`), so its MPRIS, media
    keys, notifications and portal calls never meet the user's session;
  - a **fixture**: the desktop entries, icons and settings the scenario needs,
    put on `XDG_DATA_DIRS` instead of the system's.

  The system bus is the host's (logind, NetworkManager, BlueZ, UPower): the
  instance is marked `VESHELL_PROBE_ISOLATED=1`, and the shell then only reads
  it (`ReadOnlySystemBusClient`: queries and property reads pass, every other
  call and every property write is refused). Its panels look as they do in
  the developer's session and show the host's networks, devices and battery;
  a session control it cannot perform says so in a dialog (as any failed
  session action does). `XDG_SESSION_ID`, `XDG_SEAT` and `XDG_VTNR` are not
  passed on.

  The sound server is shared: the shell waits for one at startup, and a
  private one is not worth its setup; an isolated instance can therefore play
  sounds and change volumes on the developer's machine.

  `stop` ends only the processes the instance started (veshell, its Weston,
  its bus), checked by their program and by the instance directory's name in
  their command line or environment, so a reused PID is never touched,
  and removes the control socket and the directory. A failed `start` cleans up
  the same way.

  It is reproducible and disposable: anything can be tried in it.
- **Attach.** Without an isolated instance (or with `--url`), the probe
  attaches to a running debug instance (from
  `VESHELL_VM_SERVICE_URL`, `.vscode/vmService.json`, or a scan of the ports
  from 12345), for looking at what the developer is looking at. Input (`tap`,
  `key`, `type`, `animate`'s action) only goes to the running isolated
  instance; any other instance is read-only unless `--allow-input` (the tool server's
  tools' `allowInput`) is given.

## Commands

Every command prints JSON (or writes files and prints their paths); the
tool of the same name returns the same, with images inline.

| Command | Does |
| --- | --- |
| `instances` | The running instances, and whether each serves the probe. |
| `views` | The views and their sizes. |
| `find TARGET` | Rects, visible part, opacity of the matches (`TARGET`: `type=…`, `key=…`, `text=…`). |
| `screenshot [TARGET] [--compositor]` | What a view painted, or (`--compositor`) the composited output with application windows; cropped to a widget's region. |
| `tap TARGET` / `tap --x X --y Y` | A tap on a widget's visible center, or on a point. |
| `key CHORD` / `type TEXT` | A key chord (`Enter`, `Arrow Down`, `Super+Q`); text into the focused field. Input goes through the compositor as a device's would (`--via compositor`, the default when the instance has the control socket) or straight into Flutter (`--via flutter`). |
| `animate --for MS [--tap T \| --press C \| --type X] [--frames N] [--slowdown F] [--track T…]` | Play the action slowed down and capture N evenly spaced frames: a contact sheet, each frame, and the tracked widgets' geometry per frame. |
| `state [STORE]` | A state snapshot. |
| `slowdown FACTOR` | Animations FACTOR times slower (1 restores). |
| `logs [--seconds S]` | What the instance prints and logs over the next S seconds. |
| `verify [--no-rust] [--no-dart]` | `cargo check`, `cargo fmt --check`, `cargo test`, `dart format --set-exit-if-changed`, `flutter test` (compared with the known failures), then the probe package's own format, analyze and tests. |
| `serve` | Serve the commands as JSON-RPC tools on stdio. |
| `start [--fixture NAME] [--size WxH] [--windowed]` / `stop` | An isolated instance (headless by default), used by the following commands; stopped and deleted with its display. |
| `clock freeze\|step MS\|resume\|status` | The animation clock. |
| `scenario FILE [--update-goldens \| --no-goldens]` | Run a scenario (below) on a fresh headless instance of its own, stopped after; refused while another isolated instance runs, and never on a `--url` instance. |

`animate` is the centrepiece. With the clock frozen and stepped (the default
when the instance has `ext.veshell.clock`), frame `k` shows exactly time
`k × DURATION / (N − 1)`, whatever the machine's speed. Without it, animations
play slowed down (`timeDilation`) and frames are taken at even wall-clock
intervals, at approximately those times.

## Scenarios

A scenario is a reproducible check, runnable by a developer or CI
(`extra/probe/scenarios/*.yaml`):

```yaml
name: Launching from the launcher opens the application's tile
fixture: two-apps
size: 1280x800
steps:
  # The applications load asynchronously: wait for them, not for a time.
  - wait_for: {find: text=Beta, visible: true}
  - screenshot: launcher
  - type: be
  - wait_for: {find: text=Alpha, count: 0}
  - animate:
      for: 240
      frames: 5
      key: Enter
      track: [type=PersistentWindowTileable]
  - screenshot: tile
expect:
  - find: type=PersistentWindowTileable
    count: 1
  - animation: 0
    frames: all
    find: type=PersistentWindowTileable
    visible: true
    unchanged: [left, top]
  - golden: tile
```

- **Steps**: `tap`, `key`, `type`, `wait` (ms), `wait_for` (a `find`
  condition, polled until it holds), `settle` (until the shell is idle),
  `animate`, `screenshot` (settled first unless `settle: false`;
  `compositor: true` for the composited output).
- **Expectations**: `find` (`count`, `visible`, `painted`); frames of an
  `animate` step (`frames`: `all`, `first`, `last`, `N`, `A-B`; `visible`,
  `painted`, `unchanged` coordinates of a tracked widget); `golden` (a
  screenshot against its reference, `tolerance` the share of pixels allowed to
  differ, 0.2% by default; a failed comparison writes a difference image).
  A `find` (alone or on frames) requires a match unless it expects absence
  (`visible: false`, `painted: false`, `count: 0`); `unchanged` fails on a
  frame without the widget.
- References live in `goldens/<scenario>/` next to the scenario and are
  recorded with `--update-goldens`. Fonts render differently across
  distributions, so references are only comparable in the environment that
  recorded them: elsewhere (CI), `--no-goldens` skips them and the screenshots
  are kept for review.

## Verification baseline

`extra/probe/known_failures.txt` lists the Flutter tests failing on `main`, one
per line. `verify` reports the difference: new failures fail the run, and a
known failure that passes is reported so the list can shrink. It replaces
rebuilding the baseline by stashing changes and running the suite on `main`.

## Workflow

Reproduce with `find` or `animate` (a visual bug is reproduced at the pixel
level, and the reproduction is shown to fail before any fix), fix, re-run the
same probe, then `verify`. `AGENTS.md` keeps the short version.

## Invariants

- No probe code in a release build: the shell extensions are registered under
  `kDebugMode`, the read-only system bus mode (`VESHELL_PROBE_ISOLATED`) only
  applies under `kDebugMode`, and the control socket only exists in debug
  builds of the embedder.
- One isolated instance at a time: `start` and `stop` hold
  `build/probe/instance.lock`, so separate probe processes take turns on the
  instance record.
- Neither the probe nor any test writes to the user's directories. Isolated
  instances get temporary XDG directories, and tests get directories of their
  own. (The recording tests used to publish into `~/Videos`; they now record
  into a temporary directory.)
- Captures stay local, in the probe's report directory. Attach mode captures
  whatever the developer's instance shows, so the isolated instance is the
  default.
- The probe never changes an attached instance's settings or state unless asked
  to (`--allow-input`, `clock`). The tool server resumes the clock when it
  exits; a command-line call that dies mid-`animate` leaves it to the clock's
  30 s lease. `animate` restores the speed (`timeDilation`) it found, even when
  it fails.
- The control socket is owner-only (in the user's 0700 runtime directory).
  Its requests run on the compositor's event loop: a capture renders and
  encodes there (the loop stalls for its duration, seconds at most on
  software GL), and a request waits up to 30 s for the loop. Input and
  captures are refused until the Flutter engine runs.

## Non-goals

- A replacement for widget or integration tests: a scenario that keeps
  finding a regression should become a test.
- Driving applications inside their windows beyond input injection.
- Profiling; DevTools covers it over the same VM service.

## Milestones

1. **Attach** *(done)*. The `extra/probe` package (command line and tool
   server) on an attached debug instance: `instances`, `views`, `find`,
   `screenshot`, `tap`/`key`/`type`, `animate` with `timeDilation`, `state`,
   `slowdown`, `logs`, `verify` with `known_failures.txt`; the shell's
   `views`, `find`, `act`, `capture` and `state` extensions; the documented
   loop; the tool server.
2. **Isolation and exact frames** *(done)*. `start`/`stop` with fixtures
   (`extra/probe/fixtures/`) and temporary XDG and user directories; `find`
   telling painted from laid out; `clock` (frozen, stepped) and exact
   `animate`. Left for later: `state` for the launcher's stores once they are
   on `main`, and choosing the nested window's size.
3. **Compositor and CI** *(done, CI not yet run)*. The control socket
   (`outputs`, `capture_output`, `inject`); headless instances in Weston;
   scenarios with `wait_for`, settled screenshots, frame expectations and
   reference frames; the `Probe Scenarios` workflow (manual, `--no-goldens`,
   reports uploaded). Left: a first CI run to validate its runner setup
   (UPower, PipeWire under a session bus), then running it on pull requests;
   references comparable across machines (a Nix-pinned environment for fonts).

## Acceptance criteria

- With only the probe's tools, one can tell, on a nested instance, whether the
  launcher is painted on every frame of a launch, and where the launch morph's
  icon lands relative to the placeholder's: the faults found by recordings
  during the tiled launcher work are each caught by one `animate` call.
- `animate` returns the same frames for the same scenario on two runs.
- `verify` passes on `main` with the recorded known failures, and a newly
  failing test makes it fail.
- After `start`, `stop` and a full `verify`, the user's videos, config and
  data directories are unchanged.
- A release build contains no `ext.veshell.*` extension and no control socket.

## Open questions

- Whether the CI runner's services (system UPower, PipeWire in a session bus)
  satisfy the shell's startup; the workflow is manual until a run confirms it.
- Pinning fonts (a Nix environment) so references compare across machines.
- Which named durations `animate --for` should know (`launchMorph`, the tile
  slide, the window opening), and whether the shell should list them through
  `ext.veshell.state`.
