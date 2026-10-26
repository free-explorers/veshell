# Floating window

## Description

A tile in the **floating** display mode has no dialog area. It behaves like a
regular floating compositor: the displayed window and every dialog attached to
the tile — regular top-levels included — are independently decorated,
positionable and resizable windows in one shared stack.

The stack is ordered bottom-to-top: a window that opens goes above the others,
and pressing a window raises it. Selecting the tile activates the topmost
window. Windows with `_NET_WM_STATE_ABOVE` stay above the rest of the stack
regardless of activation.

Floating mode is the escape hatch for applications that need free placement.
X11 clients such as Zoom are the reference, and client-decorated Wayland
toplevels use the same presentation. Tiled modes (`maximized`, `fullscreen`,
`game`) keep their existing architecture and are not affected by floating
behaviour.

## Placement model

Both backends use one `WindowPlacement`:

- `origin`: the compositor-global origin of the window box;
- `client_size`: the configured client-surface size;
- `geometry_offset`: the visible-content offset inside the client buffer. It is
  zero for X11 and can be non-zero for a Wayland client with CSD shadow margins.

The window's global position is kept separate from its surface-local
`geometry`. `UpdateGeometry` only carries surface-local geometry;
`SetWindowRect` is the global placement boundary. A window position never
shifts the surface or its subsurfaces inside the window.

Initial placement is compositor-owned for both backends. The shell publishes
the measured floating viewport, and Rust centres a window that the client did
not place explicitly. X11 receives a native configure at the placement origin;
Wayland receives the same origin in the model and the shell renders there.
Changes to the tile origin translate each floating window by the same delta.

A client that positions one of its own windows (an X11 application such as Zoom
placing its panels) keeps that placement: the output position is translated
into the tile coordinate space and clamped to the tile. A window the client has
not explicitly placed is centred, because the legacy launch configure leaves
every X11 window at the origin. An explicit `(0,0)` is a real position and is
kept.

A compositor-owned move may place a window partly outside the tile: at least
half of its width and height must remain inside on each axis. Client-requested
positions use the stricter inside-the-tile clamp. A size-only X11 configure
request preserves the current position; only an explicit `x`/`y` moves the
window.

For a Wayland CSD window, pointer coordinates are based on the surface-buffer
origin: `box_origin - geometry_offset`. X11 has a zero geometry offset, so its
root position is the surface origin. Flutter publishes each window's rendered
client-surface origin; popup placement is expressed relative to the owning
tile's content origin, not to the parent window. The tile popup host renders
popups directly in that space, so a popup follows its tile and is clipped to
it. Moving a parent window inside the tile does not move an X11
override-redirect popup; Wayland xdg popup positions are translated by the
Wayland adapter because their protocol position is parent-relative.

X11 override-redirect windows are categorized when they enter the model. Menus,
tooltips and regular popups stay renderable; one-pixel and non-interactive
backing windows are `helper` popups. The compositor keeps helpers for pointer
and removal bookkeeping, but Flutter filters them out of the popup stack so a
client's preview/backing windows cannot be mistaken for user-visible UI.

## Interaction

A shell-drawn title bar and a client `_NET_WM_MOVERESIZE` or
`xdg_toplevel.move` request start the same compositor-owned move. While the move
is active, pointer motion is consumed by the compositor and the resulting
placement is published to the shell.

Resize handles are drawn just outside the window box. They only request the
compositor gesture; Rust follows the pointer and publishes the new placement.
A client `xdg_toplevel.resize` or X11 resize request enters the same path.
Server-decorated and client-decorated windows use the same resize handling.
Fixed-size, fullscreen and client-maximized windows expose no resize handles.

Floating windows are never client-maximized. Entering floating mode clears a
client-maximized state, and a client maximize request while floating is answered
with an unmaximize configure. Clearing the state also restores a movable
placement (centering an unplaced window and clamping an explicit one). There is
no shell maximize/unmaximize affordance inside the floating stack to recover
from a client-maximized window, so the shell owns the free-placement contract
instead. This is not the tile's display mode, so the tile's dialogs stay
floating. The trusted file chooser keeps its modal presentation above the
floating stack.

Client-decorated windows keep their own frame and shadow. The shell does not
wrap them in a second decoration. Server-decorated windows use the shell's
title bar.

## Task bar

The floating tile has a task bar along its bottom edge, listing its windows in
creation order. The list stays stable while raising changes the paint stack, so
the entry under the pointer does not move. Windows that request
`_NET_WM_STATE_SKIP_TASKBAR` and small fixed-size or client-child panels are
left out. Pressing an entry raises and activates that window.
