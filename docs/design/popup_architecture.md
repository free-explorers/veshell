# Popup placement and hosting — design notes

Status: **implemented; runtime validation ongoing.** Branch
`feat/floating-window-placement`. Companion to
[`floating_window.md`](../specifications/floating_window.md).

## Goal

Use one popup model and one popup host for every display mode. A popup belongs
to a tile: it is contained by that tile's content area and moves with the tile.
Its placement must not depend on the live origin of its parent window.

The immediate bug is that dragging a floating X11 parent visually moves its
override-redirect children even though X11 did not move them. Maximized and
fullscreen must not become separate coordinate systems to work around that.

## Before this change

Popups were stored relative to the owning `MetaWindow` box and Flutter added the
live parent origin:

```text
position = popup.position + parentOrigin - geometry.topLeft
```

That was correct for Wayland `xdg_popup`, whose position is parent-relative by
protocol. It was wrong for X11 override-redirect windows, which are independent
top-level windows: moving the parent does not move them, and only a native
`ConfigureNotify` changes their root position.

The hosts also differed: floating mode used a tile-level overlay, while
maximized/fullscreen/game rendered popups inside `MetaSurfaceWidget`. That split
is why a placement change would otherwise need a display-mode special case.

## Invariants

1. A popup's placement is expressed in **tile-content coordinates**.
2. The tile content origin is the popup's anchor. Moving the tile moves every
   popup it owns; moving a parent window inside the tile does not move an X11
   popup.
3. `MetaPopup.parent` is ownership, z-order and lifetime. It is not the
   popup's coordinate basis.
4. Backend adapters normalize native popup coordinates at the boundary:
   - X11: root coordinates are converted to tile-content coordinates;
   - Wayland: parent-relative coordinates are converted to tile-content
     coordinates.
5. Flutter never adds a live parent origin to a popup position.
6. Rendering, pointer focus, capture and diagnostics all use the same resolved
   popup origin.
7. A tile has one popup host. Display mode changes the host rect, not the
   placement model.
8. Popups are contained by the tile content area. Any overhang is clipped by
   the host; placement is constrained so the popup stays inside where its size
   allows.
9. `MetaPopupCategory` is visibility/filter metadata only. It never affects
   placement.

## Placement model

Mirror `WindowPlacement` rather than introducing a new coordinate-space model:

```rust
/// The tile-content placement of a popup's client surface.
pub struct PopupPlacement {
    /// Popup box origin relative to the tile content origin.
    pub origin: Point<i32, Logical>,

    /// Surface-local geometry offset inside the popup buffer.
    pub geometry_offset: Point<i32, Logical>,
}
```

`MetaPopup` keeps its existing `position` and `geometry` fields. Their meaning
changes once:

- `position` is the popup box origin relative to the tile content origin;
- `geometry` remains surface-local;
- `PopupPlacement` is derived as `position` minus `geometry.topLeft`, exactly
  like `WindowPlacement` is derived from `MetaWindow`.

The Dart mirror uses the same shape and a `surfaceOrigin` getter:

```text
surfaceOrigin = origin - geometryOffset
```

This follows the existing `WindowPlacement` wording and avoids a second
vocabulary such as `positionSpace`, `ParentRelative` or `Global`.

`MetaPopupCategory` remains separate.

## Backend normalization

### X11 override-redirect

- Creation converts `surface.last_configure().loc` from the X11 root into
  tile-content coordinates using the owning tile's current content origin.
- `configure_notify` performs the same conversion. Only a popup
  `ConfigureNotify` produces a popup position patch.
- Moving or resizing the parent window inside the tile does not change the
  popup position.
- Moving the tile does not produce a popup position patch: the tile-relative
  position stays fixed, the popup host moves with the tile, and the native X11
  root is translated with the tile.

The X11 adapter therefore keeps the native popup root in
`MetaPopup.native_root` for protocol work and tile translation, while the shared
model and renderer use the tile-relative placement.

### Wayland xdg_popup

- The adapter keeps using the protocol-relative
  `get_popup_toplevel_coords()` result while constraining the popup.
- Before publishing the popup, it converts that result to tile-content
  coordinates by adding the parent **window box** origin, not the parent
  client-surface origin. The surface origin excludes Wayland CSD shadow
  margins and would shift every popup by the geometry offset.
- When the parent moves inside the tile, Rust translates the popup positions by
  the same delta and publishes the position patches.
- When the parent resizes, the existing re-constrain path recalculates the
  tile-relative position and clamps it to the tile content area.
- Nested popups continue to use the root-toplevel-relative coordinates
  produced by `get_popup_toplevel_coords()`.

This preserves Wayland's parent-relative semantics without leaking them into
the shared model or the renderer.

## Hosting

Every tile owns one popup host, regardless of display mode:

- floating stack;
- maximized content;
- fullscreen content;
- game content.

The host's coordinate origin is the tile content origin. A popup is therefore
positioned directly in host coordinates:

```text
local = popup.placement.surfaceOrigin
```

`MetaSurfaceWidget` must not render popups itself. It has no popup path; the
tile-level host renders the tile's popup ids. This is the same rule for
floating, maximized, fullscreen and game, so there is no display-mode branch in
placement.

The host is responsible for:

- clipping every popup to the tile content rect;
- constraining popup placement to the tile content rect;
- stack order within the tile;
- moving with the tile.

A popup that would extend outside the tile is clipped, not hosted in a
workspace-level overlay. This is the containment rule.

## Containment and movement

- The popup box is constrained against the parent box on creation, native move,
  parent move (Wayland), and parent resize.
- The tile host clips every popup to the tile content rect. If the popup is
  larger than the tile, its origin is pinned and the overhang is clipped.
- Moving, resizing or sliding the tile moves the host. Tile-relative popup
  positions stay unchanged, so popups follow the tile.
- Moving a parent inside the tile is not a tile move. It only moves Wayland
  popups that inherit the parent position; X11 popups stay where X11 placed
  them.

## Pointer and capture

`popup_surface_origin()` becomes the only Rust resolver. It returns the global
origin derived from the tile content origin plus the tile-relative placement:

```text
global = tileContentOrigin + popup.placement.surfaceOrigin
```

Pointer focus, native-grab bookkeeping, popup dragging and diagnostics use
this value. No parent-origin fallback is needed for an already-normalized
popup.

Capture still needs the popup origin relative to the captured window surface.
It derives that by subtracting the window's surface origin from the popup's
global origin. The capture path does not define a second placement model.

## Lifecycle and stacking

- The owning root `MetaWindow` is still the popup parent for lifetime and
  teardown.
- Removing the parent removes its popups.
- Removing a popup clears any pointer grab owned by that popup.
- Popup stack order stays stable within the tile and does not depend on the
  parent's render box.
- Helper popups remain tracked but are not rendered by the Flutter host.

## Migration

1. Change `MetaPopup.position` documentation and semantics to tile-relative.
2. Add the Rust/Dart `PopupPlacement` derivation.
3. Convert X11 creation and configure handling to tile-relative positions.
4. Convert the Wayland adapter to publish tile-relative positions and move
   popup positions when the parent moves inside the tile.
5. Add one tile-level popup host for every display mode, clip it to the tile
   content rect, and remove the embedded popup path from `MetaSurfaceWidget`.
6. Remove `parentOrigin` and `coordinateOffset` from `MetaPopupWidget`.
7. Move pointer, capture and diagnostics to `popup_surface_origin()`.
8. Update the floating specification's popup paragraph and add popup tests.

## Tests

The pure placement helpers and popup-origin resolution have automated coverage.
The following are the runtime acceptance cases; not all are automated yet.

- X11: moving the parent does not change a popup's position.
- X11: a popup `ConfigureNotify` does change its position.
- X11: moving the tile moves the popup host but leaves the popup position
  unchanged.
- Wayland: moving the parent translates its popups by the same delta.
- Wayland: parent resize re-constrains the popup inside the tile.
- Tile move: every popup follows the tile.
- Tile resize: every popup is clamped or clipped to the tile content rect.
- Pointer focus matches the rendered popup surface origin.
- Floating, maximized, fullscreen and game hosts place the same popup at the
  same tile point for the same placement.
- Fullscreen on a non-zero monitor origin.
- Helper popups stay in the model but produce no rendered surface.

## Implementation landmarks

- `MetaWindow.tile_origin` is published by `TilePopupHost` through
  `UpdateTileOrigin`.
- `TilePopupHost` is the single popup surface stack for persistent and
  ephemeral tiles.
- `MetaSurfaceWidget` no longer renders popups.
- X11 creation/configure converts root coordinates to tile-relative
  coordinates.
- Wayland creation/reposition converts parent-box-relative coordinates to
  tile-relative coordinates, and parent moves translate xdg popups.
- Pointer focus and capture resolve popups through the shared
  `popup_surface_origin()` helper.

## Open questions

- No immediate-parent z-order/transient chain is needed today: ownership is the
  root `MetaWindow`, and placement does not require the immediate parent.
- A popup larger than the tile is currently clipped rather than scaled.
