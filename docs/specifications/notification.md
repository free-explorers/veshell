# Notification

## Description

Veshell owns the session-bus name `org.freedesktop.Notifications` and serves the
[Desktop Notifications specification](https://specifications.freedesktop.org/notification-spec/latest/).
Notifications are accepted on the bus, stored in a persisted list, and surfaced
contextually depending on where the application that triggered them currently
lives.

`GetCapabilities` advertises `body`, `actions` and `persistence`: bodies and
action buttons are rendered, the `resident` hint is honored, and
`CloseNotification` is implemented.

## Responsibilities

Notification handling is split across the process boundary the same way the
xdg-desktop-portal backend is (see `src/embedder/portal/`): **Rust owns the
freedesktop D-Bus contract, the Dart shell owns state and interaction.**

| Concern | Rust (`src/embedder/notification/`) | Dart (`NotificationManager`) |
|---|---|---|
| Own the `org.freedesktop.Notifications` name | yes | no |
| Serve `GetCapabilities`, `GetServerInformation`, `Notify`, `CloseNotification` | yes | no |
| Validate signatures and marshal the `a{sv}` hints | yes | no |
| Resolve the trusted sender identity (unique name → pid) | yes | no |
| Emit `NotificationClosed` / `ActionInvoked` | on Dart's request | decides when |
| Assign ids and apply `replacesId` | no | yes |
| Persisted list, read/closed state, history | no | yes |
| Routing (pid/appId → workspace/tile/screen) | no | yes |
| Popups, expiry timers, actions, navigation | no | yes |

Rust never decides policy. An accepted `Notify` is forwarded to Dart together
with the trusted sender pid; Dart assigns the id (applying `replacesId`) and
answers, and Rust completes the D-Bus reply with that id. Signals are emitted
only when Dart asks for them, because "emit exactly once" depends on persisted
read/closed state that lives in the shell.

The Rust side mirrors the portal call bridge: the zbus interface hands every
call to the compositor loop over a calloop channel and the loop completes it —
`Notify` through a token/reply link (the D-Bus reply waits for the shell's id),
`CloseNotification` fire-and-forget. `GetCapabilities` and
`GetServerInformation` are static protocol metadata and are answered by Rust
without a shell round trip.

> **Migration status:** landed. Rust owns the name and interface
> (`src/embedder/notification/`), forwards `Notify`/`CloseNotification` to the
> shell over the platform channel, and emits the signals on the shell's behalf.
> The Dart `DbusNotificationServer` is gone; `NotificationManager` consumes the
> events and answers `Notify` with the assigned id. Calls accepted before the
> shell subscribes are queued until its `notification_ready` request.

## Persisted list

Every accepted notification is stored in `NotificationManager` (persisted key
`NotificationManager`) as a `Notification`:

- `id`: monotonically increasing server id.
- `appId`: desktop-entry id resolved from the `desktop-entry` hint, or from the
  sender's meta window.
- `dbusNotification`: the raw D-Bus payload (summary, body, hints, actions,
  `expireTimeout`, …).
- `createdAt`.
- `targetWindowId`: the `WindowId` resolved from the sender pid (see *Routing*),
  stored so the route stays stable without rescanning.
- `targetMetaWindowId`: the exact `MetaWindow` instance the notification was
  about when it was received (sender pid, or the requesting window for a
  synthesized attention notification). It is runtime identity: a relaunched app
  gets a new id, so the old notification is history. `null` when the sender has
  no window (a system sender).
- `isRead`: whether the user has already seen it. Unread notifications drive the
  workspace dot indicator, but only while `targetMetaWindowId` is still open (or
  is `null`).
- `isClosed`: whether the D-Bus `NotificationClosed` signal has already been
  emitted. A closed notification only lives in history; it has no popup and is
  never signaled closed twice.
- `isSynthetic`: whether the shell synthesized the entry from a window
  attention request instead of a D-Bus `Notify`. Synthetic entries are
  transient and never persisted (see *Window attention*).

The list is rendered by the Helm `NotificationPanel` in the overview, under a
"Notifications" title. The panel's clear-all action wipes the whole list: every
entry is closed (reason 2) and removed from the history, live popups included.
Read notifications stay in the list (history); otherwise only an explicit close
removes them. An entry that is no longer tied to an open `MetaWindow`
(`targetMetaWindowId` set but gone) is **dimmed**, so it reads as history next
to the still-actionable notifications.

A new session keeps only the history: every restored notification is loaded as
read and closed (its window belonged to a previous session anyway) and
synthesized entries are dropped.

## Routing

A notification is routed to the workspace/window of the application that sent
it. Resolution order:

1. **Sender pid** — the Rust server replaces the untrusted `pid` argument with
   the real session-bus sender pid (`GetConnectionUnixProcessID`), mapping to a
   meta window and then to a `WindowId`. A **dialog** resolves to its parent
   persistent tile by walking the meta-window parent chain.
2. **`desktop-entry` hint** — best persistent tile whose `properties.appId`
   matches.
3. Otherwise the notification is **unresolved**.

Given a target window, the route is:

| Situation | Target | Surface |
|---|---|---|
| persistent tile in another workspace | `WorkspaceNotificationTarget` | popup next to that workspace button + unread dot on the button |
| persistent tile in the focused workspace, tile hidden | `TileNotificationTarget` | popup below that tileable panel button |
| persistent tile displayed | `DisplayedNotificationTarget` | persisted list only (marked read) |
| ephemeral window shown in the open overview | `EphemeralDisplayedNotificationTarget` | hidden (overview visible) |
| system notification / no target | `UnresolvedNotificationTarget` | default popup on the focused screen |

"Focused workspace" is the selected workspace of `focusedScreenProvider`. A tile
is *displayed* when it belongs to the focused workspace and its index falls in
the visible range of the workspace's sliding container. That container also
holds the persistent application launcher appended after the windows, so
selecting the launcher scrolls the last window out of view and the notification
pops below its panel button instead of counting as displayed. An ephemeral window
is displayed while its screen's overview is open.

When the pid can only be resolved to an app id, the best tile is picked among
the app's tiles: a displayed one wins (so the notification counts as displayed),
then one in the focused workspace, then any other.

Popups are anchored so their **top-left corner sits next to the target**: to the
right of the target for the workspace/default anchors, below the target for the
tileable anchor. Tileable popups are hosted by a workspace-local overlay, so
they are clipped and scrolled away with the workspace instead of floating from
the root overlay.

## Popups and lifetime

Popups are **one-shot**: they are pushed once, when the notification is
received, in the channel matching its route:

- `workspace:<workspaceId>` for workspace targets,
- `window:<uuid>` for tile targets,
- the screen id for default/unresolved targets,
- displayed targets (tile or ephemeral-in-overview) get no popup.

A dismissed or expired popup is never shown again; only the overview list and
the workspace dot keep track of it. Their duration follows the D-Bus
`expireTimeout`:

- `> 0`: that many milliseconds,
- `-1`: `defaultNotificationPopupDuration`,
- `0`: no automatic expiry (dismissed or read only).

Removing a popup cancels its expiry timer, so an explicit close never emits a
spurious expiry.

## Actions and closing

The spec's `actions` argument is a flat `[key, label, key, label, …]` array.
Each pair becomes a button; the reserved `default` key is instead invoked by
clicking the notification body. Actions are hidden once the notification is
closed.

Invoking an action emits `ActionInvoked(id, key)` and marks the notification
read. Unless the `resident` hint is set, the notification is then closed
(reason 2); a resident notification stays on screen until dismissed or closed.

Before `ActionInvoked`, the shell asks the compositor to mint an **activation
token** for the notification's target window and emits the spec's
`ActivationToken(id, token)` signal. An app whose action opens its own window
hands that token to `xdg_activation_v1`; the compositor honors a token it
minted for an invoked action by focusing the window (see *Window attention*)
and then asks the shell (`window_activation_requested`) to bring it into view:
the shell owns the workspace and tile, so the compositor's focus alone would
leave the window off-screen. Inline actions that do not want the window forward
simply ignore the token, so clicking "Mark as read" never steals focus. A
notification with no target MetaWindow (a system sender) gets no token.

Every live notification is closed exactly once, emitting `NotificationClosed`
with the spec reason:

- `1` — the popup expired,
- `2` — the user dismissed it or invoked a closing action,
- `3` — a client called `CloseNotification`.

Closing is idempotent: a notification that already expired (and stays in
history unread) is not signaled again when the user later deletes it. Closing
a popup—by expiry, dismissal, activation or a client's `CloseNotification`—only
tears down the live popup: the entry stays in the persisted list so the Helm
notification center keeps the **full history**. Only deleting an entry from
that center removes it.

## Opening the source window

Clicking the body of a notification—when it has no `default` action—brings the
window that sent it into view (`window_navigation.dart`). The notification is
closed (reason 2) and marked read as part of the navigation.

- A **persistent tile** focuses its screen, hides the overview (which would
  otherwise cover the workspace), then selects its workspace and tile.
- An **ephemeral window** focuses its screen and opens the overview to that
  specific window (`Overview.focusedWindowId`).
- A **dialog** resolves to its parent tile.

The owning meta window is also activated on the compositor, so it receives
keyboard focus (and is raised for X11).

A `Notify` with a `replacesId` pointing at a live notification updates that
entry in place, reusing its id, dropping the old popup and re-routing the new
one. A `replacesId` for an unknown or already closed id creates a new
notification as usual.

## Window attention

A window can ask for the user's attention instead of being brought forward
directly. The compositor forwards the request and the shell synthesizes a
notification from it; the compositor never focuses or navigates to the window
on its own. Two sources feed the same event:

- X11 `_NET_WM_STATE_DEMANDS_ATTENTION` (Smithay's `demands_attention_request`)
  emits `window_attention_requested { metaWindowId }`; clearing it emits
  `window_attention_released { metaWindowId }`.
- Wayland `xdg_activation_v1` when the activated surface already has a meta
  window emits `window_attention_requested { metaWindowId }`. A request for a
  surface with no meta window yet keeps its existing "opened from" meaning and
  is **not** an attention request (it is a launch, not a background demand).
  A request carrying a token the notification server minted for an invoked
  action is not a demand either: it focuses that window, because the user asked
  for it (see *Actions and closing*).

`NotificationManager` synthesizes a `Notification` (summary `"<App> requests
attention"`, no body) and routes it with the ordinary rules, so a window in
another workspace pops next to its workspace button and one hidden in the
focused workspace pops below its panel button. The request is remembered per
meta window: a repeated demand does not stack, and `window_attention_released`
drops the live popup.

A synthesized notification has no D-Bus sender. Its `isSynthetic` flag
suppresses `NotificationClosed`/`ActionInvoked`, and it is created with
`expireTimeout = -1` (server default). Clicking the body reuses click-to-open:
the window is brought into view and the entry is closed (reason 2). A window
that is already displayed (or shown in an open overview) is skipped entirely,
which also keeps a freshly launched window that activates itself from
producing a spurious entry.

Synthesized attention notifications are **transient**: they never enter the
persisted history or the overview notification center (`NotificationList`
excludes them), and any entry restored from storage on startup is dropped.
Unlike a history entry, when the popup **expires** the notification is kept
unread in memory, so its workspace dot survives while the window is open. The
entry is forgotten once it is seen (clicked, dismissed, or its window becomes
displayed), once `window_attention_released` arrives, or once its window
closes. Its unread dot is therefore only ever shown while the exact window is
still open.

## Read state

`NotificationReadTracker` reacts to route changes only:

- a notification is marked read once its tile is displayed, once its workspace
  becomes the displayed one (clearing the workspace dot), or once its ephemeral
  window is shown in the open overview; its live popup is then closed
  (reason 2);
- because tile popups live in the workspace overlay, leaving the workspace
  scrolls/clips them away rather than tearing them down;
- dismissing or activating a popup marks the notification read; an expiry does
  not, so its unread dot survives.
- invoking an action marks the notification read.

Notifications are never re-surfaced after being dismissed.

The workspace dot additionally requires the notification's `targetMetaWindowId`
to still be open (`unreadNotificationsForWorkspace`). A notification whose
window closed becomes history: its dot clears even if it was never seen, and it
is dimmed in the center. A notification with no MetaWindow (`null`) is not tied
to a closed window and stays live.

## Transport

`src/embedder/notification/` owns the freedesktop D-Bus surface and the shell
owns the state; the two sides talk over the platform channel:

- Rust → Dart: `notification_received { callToken, notification }` (the
  payload is the raw `Notify` arguments plus the trusted sender pid, with the
  `a{sv}` hints already marshalled to the `NotificationHints` field names),
  `notification_close_requested { id }`, and the window-attention events
  `window_attention_requested { metaWindowId }` /
  `window_attention_released { metaWindowId }` (the shell synthesizes the
  notification, so there is no D-Bus call to answer), plus
  `window_activation_requested { metaWindowId }` (a trusted activation token
  focused a window, so the shell brings it into view).
- Dart → Rust: `notification_notify_result { callToken, id }` (completes the
  pending `Notify` with the shell-assigned id), `notification_action_invoked
  { id, actionKey }` and `notification_closed { id, reason }` (emit the
  signals), `notification_activation_token { id, metaWindowId }` (mint an
  activation token for the target window and emit `ActivationToken`), and
  `notification_ready` (the shell has subscribed).

`GetCapabilities` and `GetServerInformation` are static protocol metadata
answered by Rust without a shell round trip. A call accepted before
`notification_ready` is queued and flushed on that request, so `Notify` is never
dropped during startup and never pushed to a shell that cannot receive it.

## Out of scope (future milestone)

Action icons (`action-icons`) and hint-driven surfacing
(urgency/transient/category).
