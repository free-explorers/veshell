# Matching Algorithm

## Goal
Having persistent windows is a key feature of Veshell. It allows users to have a consistent experience across reboots and app restarts.
To do so we need to be able to assign a new application session to an already existing window placeholder.

## Considered Scenarios
The challenge come from the fact that there is no way to predict how an application will behave while starting and therefore we need to be able to detect and handle different scenarios.

For each scenario, the signals below are listed from the most reliable to the weakest fallback. A signal that is unavailable (or not specific) falls through to the next one.

### Single Window: one Persistent placeholder receives a single Wayland surface
This is the most common scenario. The application starts (or is already running) and creates a single Wayland surface that must be assigned to its Persistent placeholder.
Dialog and child windows are handled separately, see [Dialog / Child Window](#dialog--child-window).

Signals, in order of reliability / fallback:
1. Tracked launch provenance — the placeholder that launched the application.
2. Waiting placeholder — the placeholder armed at launch and expecting a surface.
3. Application identity — desktop-entry-resolved `appId` matching an existing placeholder.
4. Window title — matches the placeholder's stored title.
5. Process grouping — same `pid` or `app-*.scope` cgroup.
6. Fallback — no matching placeholder: create a new persistent window.

### Sequential Windows: Application that when launched create multiple windows sequentially
For applications that have a splash screen or a loading screen. The application starts and creates a new Wayland or XWayland window, then it creates another window.
Here we don't want to create two different Persistent window but instead display them sequentially in the same Persistent window.
The difficulty here is that the lifetime of each windows can overlap.

Signals, in order of reliability / fallback:
1. Tracked launch provenance — both windows inherit the launch cgroup, so they belong to the same tile.
2. Explicit protocol relations (`parent`, `xdg_activation_v1`) — the second window is usually opened by the first.
3. Process grouping — same `pid` / `app-*.scope`.
4. Application identity — same `appId`, confirming the same tile.
5. Window title — used to choose which overlapping surface to display, by matching the tile's title.
6. Order and time — the first mapped surface is presumed transient; once it closes the tile settles on the best remaining match.

### Parallel Windows: Application that when launched create multiple windows in parallel to restore a session
Applications that create several windows when launched to restore previously opened windows. Typically for browsers or IDEs or documents viewers.
In this case however we want to restore each surfaces in its own Persistent window.
Child and dialog surfaces encountered during the burst are routed first by [Dialog / Child Window](#dialog--child-window) and never claim a tile.

Signals, in order of reliability / fallback:
1. Application identity — same desktop-entry-resolved `appId`, defines the peer set of placeholders.
2. Tracked launch provenance — the launch/instance the whole set belongs to (when launched through a placeholder).
3. Process grouping — same `pid` / `app-*.scope`, confirming a single instance.
4. Window title (specific) — the discriminator between the peer placeholders.
5. X11 `windowClass` / `startupId` — additional identity when available.
6. Provisional assignment and bounded correction — when titles are late or generic, place immediately and correct silently up to the correction bound; if no placeholder matches, fall back to a new placeholder.

### Dialog / Child Window: a window opened on behalf of another
An application opens a transient window (dialog, modal, About, file picker), or a helper process opens a window on the application's behalf.
In this case the window must attach to the owner's tile instead of opening a new one.

Signals, in order of reliability / fallback:
1. Explicit `parent` — authoritative owner.
2. `xdg_wm_dialog_v1` hint (`Dialog`/`Modal`) — authoritative.
3. `xdg_activation_v1` relation — the requesting surface is the owner.
4. Window shape — `min == max` on both axes (fixed-size) strongly suggests a dialog.
5. Process grouping — same `pid` / `app-*.scope` as the owner.
6. Tracked launch provenance — the helper inherits the launch cgroup.
7. Fallback — attach as a dialog to the best-matching tile rather than a standalone tile.

## Signals available
In order to help us match the surfaces and the persistent windows use the following datas.

None of these signals is authoritative on its own, and every one may be absent, late, or misleading depending on the application and the toolkit it uses.

### Client / protocol signals

- **Application ID (`appId`) / X11 `WM_CLASS`** — always available, medium reliability.
  - Source: `xdg_toplevel.app_id`; X11 class and instance.
  - Notes: can be hollow or a helper identity (`electron`, runtime names) and can change after the window is mapped. Normalised to a desktop-entry id when possible (Flatpak/Snap, desktop database, binary name). Primary application-level identity.
- **Window title (`title`)** — usually available, but often only after the first commit; high reliability when specific, none when generic.
  - Source: `xdg_toplevel.title`; X11 title.
  - Notes: frequently the only signal that distinguishes several tiles of the same application (see [parallel windows](#parallel-windows)). Generic during startup (`Code - OSS`), then becomes specific; can change repeatedly.
- **Process ID (`pid`)** — always available; weak as an identity, strong as a join key.
  - Source: Wayland client credentials; X11.
  - Notes: multi-process applications report helper pids and the launched pid usually differs from the window pid. Mainly used to join the process-based signals below.
- **Parent (`parent`)** — only when the client sets it; authoritative when present.
  - Source: `xdg_toplevel.set_parent`; X11 transient.
  - Notes: declares the owning toplevel. Many toolkits (Electron) never set it.
- **Activation relation** — only when the client uses the protocol; high reliability (per-window "opened from").
  - Source: `xdg_activation_v1` token (`surface`, `serial`).
  - Notes: carries the surface that requested the activation, which is often the owner of a newly opened window. Not universal.
- **Dialog hint** — only when the client uses the protocol; authoritative when present.
  - Source: `xdg_wm_dialog_v1` (`Dialog`/`Modal`).
  - Notes: distinguishes dialogs and modals from regular windows. Used by e.g. GTK, not by Electron.
- **Startup ID (`startupId`)** — X11 only; low reliability.
  - Source: X11.
  - Notes: rarely set; mostly absent for native Wayland clients.
- **Geometry hints** — always available; medium reliability.
  - Source: committed `min`/`max` size and modal state.
  - Notes: `min == max` on both axes indicates a fixed-size window; modal is a dialog indicator.
- **Role and popup parent** — always available; authoritative.
  - Source: `xdg_toplevel` / `xdg_popup`.
  - Notes: popups and menus belong to their parent surface and never become tiles.

### System signals

- **Application cgroup (`app-*.scope`)** — medium-high reliability.
  - Source: `/proc/<pid>/cgroup`.
  - Notes: per-application, not per-window; useful to relate helper processes. Shared wrapper/session scopes are not reliable.
- **Tracked launch cgroup (`veshell-launch-*.service`)** — high provenance.
  - Source: the shell's own launcher.
  - Notes: attributes any descendant process of a tracked launch to the launching tile, including helper processes that report another app id.
- **Flatpak / Snap application id** — high reliability.
  - Source: `/proc/<pid>/root/.flatpak-info`, `/proc/<pid>/attr/current`.
  - Notes: authoritative application identity for sandboxed applications.
- **Binary name** — low reliability.
  - Source: `/proc/<pid>/comm`.
  - Notes: last-resort application identity when nothing else resolves.
- **Desktop entries** — high reliability.
  - Source: freedesktop database.
  - Notes: maps an application id to a desktop-entry id, name, exec and categories; used to normalise identities.
- **Focus / activation history** — medium reliability.
  - Source: shell.
  - Notes: records which tile or surface the user recently acted on.
- **Wall-clock time** — informational.
  - Source: shell.
  - Notes: used to bound how long an association may still change.

### Shell / persisted signals

- **Tile identity (`appId`, stored title, `windowClass`, `startupId`, custom exec)** — high reliability if kept stable.
  - Notes: the reference an incoming window is compared against. Must represent the tile durably and must not be overwritten by whatever the currently displayed window reports.
- **Tile placement (workspace, screen) and display mode** — high reliability.
  - Notes: persisted across restarts.
- **Waiting / expecting state after a launch** — medium reliability.
  - Notes: marks the tile that launched an application; currently cleared as soon as a window attaches.
- **Provenance map (pid → tile)** — high reliability while the tracked launch is alive.
  - Notes: links a running process to the tile that started it.
- **Current window ↔ tile map** — high reliability.
  - Notes: existing associations, used to detect and avoid double assignment.

All of these are observed on the live surfaces and, where meaningful, mirrored on the persistent tile so that a new session can be matched against the previous one. Only durable identity should be stored on the tile; transient display data must not overwrite it.

## Matching Algorithm

When a new Surface is created we try to match it against the existing persistent windows sharing the same application ID.

If no matching is found we create a new persistent window for the surface.

Else we assign the surface to the matching persistent window with the best matching score.

For cases like [sequential windows](#sequential-windows) and [parallel windows](#parallel-windows) we can have multiple surfaces assigned to the same persistent window. Since we can display only one surface at a time we we compare their matching score and display the one with the best matches.

In order to handle the [sequential windows](#sequential-windows) we expect that the extra surface close itself after a short delay which we leave us with a single surface to display.

And to distinguish between the [sequential windows](#sequential-windows) and for the [parallel windows](#parallel-windows) we use the extra delay awaited to listen for any changes in the surface properties to match thoses surfaces against other persistent windows sharing the same Application ID.

After a fixed delay a single surface is kept for each persistent window and a new persistent window is created for each extra surface.


