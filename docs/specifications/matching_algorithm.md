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
2. Window title (specific) — the discriminator between the peer placeholders. This is the key signal: the native window goes to the placeholder whose stored title matches it, regardless of which placeholder was launched.
3. Tracked launch provenance — the launch/instance the whole set belongs to (when launched through a placeholder).
4. Process grouping — same `pid` / `app-*.scope`, confirming a single instance.
5. X11 `windowClass` / `startupId` — additional identity when available.
6. No placeholder matches — attach as a dialog of the closest placeholder. Never create a new placeholder automatically: placeholders are user-created only (app launcher, or manual conversion of a toplevel/dialog).

### Dialog / Child Window: a window opened on behalf of another
An application opens a transient window (dialog, modal, About, file picker), or a helper process opens a window on the application's behalf.
In this case the window must attach to the owner's tile instead of opening a new one.

Signals, in order of reliability / fallback:
1. Client-declared `parent` (`xdg_toplevel.set_parent`, X11 transient) — authoritative, makes the window a dialog of the parent's tile.
2. `xdg_wm_dialog_v1` hint (`Dialog`/`Modal`) — authoritative.
3. Window shape — `min == max` on both axes (fixed-size) **with a resolvable owner relation** strongly suggests a dialog.
4. `activatedBy` (`xdg_activation_v1`) — **owner hint only**, never a dialog trigger by itself: it only says the window was opened from another, so it picks the owner when the window is a dialog for other reasons.
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
  - Notes: declares the owning toplevel and marks the window as a dialog of that owner's tile. Many toolkits (Electron) never set it. Kept strictly separate from `activatedBy`.
- **Activated by (`activatedBy`)** — only when the client uses the protocol; high reliability as an "opened from" hint, none as a dialog signal.
  - Source: `xdg_activation_v1` token (`surface`, `serial`).
  - Notes: the surface whose activation opened this window, often its owner. Used only to pick a dialog's owner, never to turn a regular toplevel into a dialog. Recorded independently of `parent`, so a window can have both. Not universal.
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
- **Tracked launch cgroup (`veshell-launch-<tile-uuid>-<launch>.service`)** — high provenance.
  - Source: the shell's own launcher.
  - Notes: attributes any descendant process of a tracked launch to the launching tile, including helper processes that report another app id. The tile uuid is part of the unit name, so a tile is recognized from a process cgroup alone — no lookup table — across relaunches and shell restarts. A single-instance application keeps the cgroup of its first launch, so relaunching it (which only asks the running instance to open a window) does not lose attribution.
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
- **Launch cgroup prefix (pid → tile)** — high reliability as long as the launch cgroup exists.
  - Notes: links a running process to the tile that started it by matching the
    `veshell-launch-<tile-uuid>-` prefix in `/proc/<pid>/cgroup`, derived from the
    tile id rather than stored. It does not depend on the `systemd-run` supervisor
    process: a bootstrapper can hand over and return while the application keeps
    running (Steam does), and the same tile relaunching the application starts a
    new unit while the running instance keeps the first one's cgroup.
- **Current window ↔ tile map** — high reliability.
  - Notes: existing associations, used to detect and avoid double assignment.

All of these are observed on the live surfaces and, where meaningful, mirrored on the persistent tile so that a new session can be matched against the previous one. Only durable identity should be stored on the tile; transient display data must not overwrite it.

## Matching Algorithm

### Principles

- **Gather, then decide by title.** The clicked tile collects the whole launch
  burst (its waiting bonus stays armed for the duration), and only once the
  burst has settled and titles are final is ownership decided by title. There
  is **no priority for the clicked tile in keeping**: a sibling whose stored
  title matches a window takes it.
- **Order independence.** The mapping order of a burst is not stable and must
  not influence the result; exact ties are broken by a fixed, reproducible key.
- **No automatic placeholders.** Extra windows never create a
  `PersistentWindow`. Placeholders are created only by explicit user action
  (app launcher, or manual conversion of a toplevel/dialog). A leftover window
  spreads to an empty same-app sibling, or becomes a dialog when none is free.
- **One displayed surface per tile.** A tile may own several native windows
  (sequential splash/overlap): it displays the best-matching one and spreads or
  dialogues the rest.
- **Dialogs stay visible.** A dialog is attached to its owner tile and rendered
  above the tile's displayed surface, never hidden.
- **One redistributor, displayed window included.** The same pass runs for the
  clicked tile at its burst settle and for any other tile with an overflow. No
  tile — launched or not — keeps a window it does not fit.
- **A stored identity follows the displayed window.** Once a tile has settled
  (single window, not gathering), it adopts the title, class, startup id and pid
  of the window it displays; the tile's desktop-entry `appId` is preserved. An
  empty tile keeps the identity of the last window it showed, so a relaunch
  finds it again. The identity is never refreshed mid-burst: the displayed
  window is transient then and adopting it would overwrite the title the
  redistribution matches against.

### Flow

1. **Launch and gather.** The user launches a tile. Its waiting bonus stays
   armed for the whole burst, so every native window of the burst attaches to
   the clicked tile first.
2. **Settle.** After the burst's last change (short debounce) titles are final;
   no dispatch decision is taken before that. This is what removes the need for
   any later re-association.
3. **Redistribute by identity, displayed window included.** For each owned
   window, a sibling whose match cost is strictly lower (principally a stored
   title match; provenance/process-sibling recovery also counts) wins it,
   strongest first, destinations deduped; a taken destination falls through to
   the next best. Equal cost keeps the window where it is. Within a tile that
   owns several windows, the displayed one is chosen by the same identity cost
   plus a penalty for fixed-size windows: the application's real (resizable)
   window wins over a transient fixed-size helper such as Discord's updater,
   which is then the leftover to turn into a dialog. That penalty orders
   windows only inside the tile; the matcher and the sibling comparison stay
   on the unpenalised cost.
4. **Spread leftovers.** A window left without a better home is moved to an
   empty same-app sibling if one exists, instead of becoming a dialog.
5. **Dialog only when no sibling is free.** A leftover that finds no empty
   sibling becomes a dialog of its tile.
6. **Reopen when emptied.** If the clicked tile had received a window and ended
   with none, it reopens one window, bounded to a single attempt. A launch that
   never produced a window is never relaunched.

### Dialog routing

A window is routed to a dialog before ordinary matching when it has a
client-declared `parent`, a modal hint (`xdg_wm_dialog_v1` Modal / X11 motif
modal), or a fixed size **with a resolvable owner relation** (parent,
tracked-launch provenance or process sibling) — a lone fixed size never turns a
regular toplevel into a dialog. The activation relation (`activatedBy`) is only
an owner hint: it never makes an otherwise regular toplevel a dialog, so an
activated browser tab still goes through normal matching and lands on an empty
same-app tile when one is available. The owner is resolved by client `parent`,
then `activatedBy`, then provenance, then process sibling, falling back to the
ordinary best candidate for an authoritative hint. Owner resolution always walks
dialog chains up to the owning tile, so a native window is never nested under
another dialog. A client-parent/modal hint that arrives after mapping re-routes
the already-matched window while it is still inside its settle window.

A tile renders its dialogs whether or not it currently has a main window
(`WindowDialogs`, shared with `WindowWidget`): when the only windows an
application opened so far are dialog-like (for example an updater or a splash
that reports a fixed size before the real window appears) they are shown as
floating surfaces over the empty tile, rather than hidden behind its
placeholder.

### Tie-break

A deterministic tie-break is needed when two candidate placeholders are
indistinguishable on every signal (same stored title, class, startup id, pid)
or when two siblings match the same title. The destinations are then
equivalent, but the choice must not depend on the unstable map order, so it is
broken by a fixed key. The tie-break never overrides a better match.


