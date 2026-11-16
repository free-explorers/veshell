# SystemTray

## Description

Applications that live in the background (chat clients, sync tools, game
launchers, network and audio applets) put an icon in the system tray. Veshell
implements the [StatusNotifierItem specification](https://www.freedesktop.org/wiki/Specifications/StatusNotifierItem/)
— the protocol of Qt, KDE, Electron and libappindicator/Ayatana
applications — with menus over `com.canonical.dbusmenu`. The X11 XEmbed tray
is not supported.

The tray is shown in two places:

- the **Helm** lists every item in a *Background Apps* card of the control column
  (after the media control), with its name, passive items included;
- the **status bar** (top panel or notch, see the `theme.statusBar` setting)
  shows the items' icons before the system status, unless
  `theme.statusBarContent.showSystemTray` is off. It leaves out passive items,
  which have nothing to report, and shows all the others: the notch grows to
  fit them. The tray icons are the only part of the notch that answers
  clicks; its other items stay indicators.

## Responsibilities

The tray splits across the process boundary like the notification server
(see the [service boundary](readme.md#service-boundary)): the watcher is a
name Veshell owns, the items are services the applications own.

| Concern | Rust (`src/embedder/system_tray/`) | Dart (`SystemTrayManager`) |
|---|---|---|
| Own `org.kde.StatusNotifierWatcher` (and `org.kde.StatusNotifierHost-<pid>`) | yes | no |
| Serve `RegisterStatusNotifierItem`, the properties and the signals | yes | no |
| Drop an item when its bus name loses its owner | yes | no |
| Resolve the item's pid (bus driver) | yes | no |
| Read the item's properties and follow its `New*` signals | no | yes |
| `Activate`, `SecondaryActivate`, `Scroll`, `ContextMenu` | no | yes |
| Read and drive the `com.canonical.dbusmenu` menu | no | yes |
| Mint the trusted activation token | yes | asks for it |

The watcher runs on its own thread; only registration changes cross to the
compositor loop. Like the notification server, only the real seat session
(DRM backend) and the probe's isolated instance own the name, so a nested run
does not take over the tray of the desktop it runs in.

## Watcher

`RegisterStatusNotifierItem(service)` accepts what applications send:

- a bus name: the item is at `/StatusNotifierItem` on it (KDE, Qt);
- an object path: the item is at that path on the sender's connection
  (libappindicator, Ayatana, Electron);
- a bus name directly followed by a path.

The item id, as `RegisteredStatusNotifierItems` and the signals carry it, is
the bus name followed by the path. Registering a known item again is ignored.
An item is unregistered when the name it was registered under loses its owner:
the application quit, or it released its well-known name to hide the icon
while staying connected.

`IsStatusNotifierHostRegistered` is always true: the shell is the host, and
reporting it from the start keeps applications that start with the session
from falling back to an X11 tray before the shell has subscribed.
`RegisterStatusNotifierHost` is accepted and ignored. `ProtocolVersion` is 0.

## Host

The shell reads each item with `GetAll` on `org.kde.StatusNotifierItem` and
shows it once that succeeds (an application that registers its item a moment
before exporting it gets one retry). Any signal of the interface triggers one
debounced re-read; `NewStatus` is applied at once. A property that is missing
or wrongly typed keeps its default, so an incomplete item is still shown.

| Property | Use |
|---|---|
| `Id`, `Title`, `ToolTip` | the item's name (title, then tooltip title, then id) and its tooltip; the tooltip description's markup is reduced to text |
| `Status` | `Passive` dims the item in the Helm and hides it from the status bar; `NeedsAttention` switches to the attention icon, when there is one |
| `IconName`, `AttentionIconName`, `IconThemePath` | an absolute path, else the item's `IconThemePath`, else the icon theme |
| `IconPixmap`, `AttentionIconPixmap` | when the name does not resolve: the smallest pixmap at least as large as the icon, converted from network-order ARGB32 |
| `ItemIsMenu` | a primary click opens the menu instead of `Activate` |
| `Menu` | the `com.canonical.dbusmenu` object; `/` means none |

### Interaction

| Input | Call |
|---|---|
| Primary click | `Activate(x, y)`; the menu when `ItemIsMenu`, or when `Activate` fails (items that only offer a menu) |
| Secondary click | the menu; `ContextMenu(x, y)` when the item exports none (or an empty one) |
| Middle click | `SecondaryActivate(x, y)` |
| Scroll | `Scroll(delta, orientation)`: one step per wheel notch or per 50 px of touchpad travel, positive up and right |

`x, y` are the click's global position in logical pixels.

### Activation

An application that shows its window when activated asks the compositor for
focus through `xdg_activation_v1`. Without a token tied to a user action, the
compositor reads that as a demand for attention. Before `Activate` and
`SecondaryActivate`, the shell therefore asks the compositor for a trusted
token (`system_tray_activation_token`) and hands it to the item with
`ProvideXdgActivationToken`. The token names no window: whichever surface the
application activates with it is focused and its meta window flagged
`navigationRequested`, as for a notification action (see
[Notification](notification.md), *Actions and closing*). The shell navigates
to a flagged window as soon as it has a tile, then clears the flag: an
application whose window was closed to its tray creates a new one, which is
activated moments before the shell matches it to its tile.

Applications that do not implement `ProvideXdgActivationToken` (Chromium and
Electron ones: Discord, Signal, Slack, VS Code) answer an error and activate
their window with a token of their own, which names no requesting window. The
token request therefore also grants the item's process (the pid the watcher
resolved): for three seconds, its first activation of one of its existing
windows is honored the same way. The grant is single use and only applies to
that process's own windows.

### Menu

The menu is read when it is opened: `AboutToShow(0)`, then
`GetLayout(0, -1, properties)`, and drawn as a Material menu anchored to the
item. Entries honor `type` (separators), `label` (mnemonic underscores
removed), `enabled`, `visible`, `icon-name`, `icon-data`, `toggle-type` and
`toggle-state` (checkboxes and radio buttons) and `children-display`
(submenus). Opening a submenu sends `AboutToShow` for it and re-reads the
layout if the application asks. While the menu is open, `LayoutUpdated` and
`ItemsPropertiesUpdated` re-read it. Choosing an entry sends
`Event(id, "clicked")`, after the same trusted activation as `Activate` (see
*Activation*): an entry such as "Open" shows the application's window.
Opening and closing a menu send `opened` and `closed`.

## Transport

- Rust → Dart: `system_tray_item_registered { id, busName, objectPath, pid }`
  and `system_tray_item_unregistered { id }`.
- Dart → Rust: `system_tray_ready` (the shell has subscribed: the compositor
  delivers every item registered so far, then the changes; a reloaded shell
  asks again and gets the whole set again) and
  `system_tray_activation_token` (answers a trusted activation token).

## Out of scope (future milestone)

The X11 XEmbed tray, overlay icons (`OverlayIconName`, `OverlayIconPixmap`),
`AttentionMovieName`, menu shortcuts (`shortcut`), keyboard navigation from the
status bar into the tray, and choosing which items the status bar shows.
