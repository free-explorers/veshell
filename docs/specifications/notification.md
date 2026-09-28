# Notification

## Description

Veshell owns the session-bus name `org.freedesktop.Notifications` and serves the
[Desktop Notifications specification](https://specifications.freedesktop.org/notification-spec/latest/).
Notifications are received in Dart (`DbusNotificationServer`), stored in a
persisted list, and surfaced contextually depending on where the application
that triggered them currently lives.

`GetCapabilities` advertises `body`, `actions` and `persistence`: bodies and
action buttons are rendered, the `resident` hint is honored, and
`CloseNotification` is implemented.

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
- `isRead`: whether the user has already seen it. Unread notifications drive the
  workspace dot indicator.
- `isClosed`: whether the D-Bus `NotificationClosed` signal has already been
  emitted. A closed notification only lives in history (keeping its dot until
  seen); it has no popup and is never signaled closed twice.

The list is rendered by the Helm `NotificationPanel` in the overview. Read
notifications stay in the list (history); only an explicit close removes them.

## Routing

A notification is routed to the workspace/window of the application that sent
it. Resolution order:

1. **Sender pid** — the generated D-Bus server replaces the untrusted `pid`
   argument with the real session-bus sender pid (`GetConnectionUnixProcessID`),
   mapping to a meta window and then to a `WindowId`. A **dialog** resolves to
   its parent persistent tile by walking the meta-window parent chain.
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
the visible range of the workspace's sliding container. An ephemeral window is
displayed while its screen's overview is open.

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

## Read state

`NotificationReadTracker` reacts to route changes only:

- a notification is marked read once its tile is displayed, once its workspace
  becomes the displayed one (clearing the workspace dot), or once its ephemeral
  window is shown in the open overview; its live popup is then closed
  (reason 2);
- because tile popups live in the workspace overlay, leaving the workspace
  scrolls/clips them away rather than tearing them down;
- closing a popup marks the notification read.
- invoking an action marks the notification read.

Notifications are never re-surfaced after being dismissed.

## Out of scope (future milestone)

Activation tokens, click-to-open of the related window, action icons
(`action-icons`), and hint-driven surfacing (urgency/transient/category).
