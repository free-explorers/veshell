# Tile grab

## Description

`Super` + primary-button drag anywhere on a [PersistentWindow](persistent_window.md)
tile holds the whole tile. While it is held, the tile can be dropped on
another tile to reorder it, carried to another screen or monitor, or dropped
on a workspace button in the screen panel. `Super+W/S/A/D` keeps navigating
the screen under the pointer, so the layout slides beneath the held tile and
it can be carried to a workspace or position that is not on screen yet.

It is the pointer counterpart of `Super+Shift+W/S/A/D` (`MoveIntent`, see
[Navigation](navigation.md)), and it also crosses monitors.

## Split

| Concern | Owner |
| --- | --- |
| Starting a grab, claiming the press from the tile's controls and client | `TileGrabRegion` (wraps every persistent tile) |
| Tracking the pointer, resolving the drop target, applying the drop | `TileGrabController` (`tile_grab_controller.dart`) |
| Drop targets | `TileRowMarker` (each workspace's row of slots, attached by `SlidingContainer`), workspace buttons, `TileGrabScreenMarker` on each screen |
| Tiles sliding aside to open and close gaps | `TileDropSlot` (each tile slot of a workspace, launcher included), `tileDisplayIndex` |
| The held tile under the pointer, and its flight on release | `TileGrabPreview` (one per monitor view) |
| Redirecting navigation to the screen under the pointer, Super release | `VeshellShortcutManager` |

## Interaction

- The press is a grab when `Super` is held and the primary mouse button goes
  down inside a tile. A game tile is excluded: the client owns its pointer.
- The press belongs to the shell. It wins the gesture arena, so buttons, title
  bars and swipes inside the tile do not react, and a client surface does not
  forward it (`TileGrabRegion.claims`). The client never sees the press nor its
  release.
- The tile itself comes off its slot, drawn on every monitor it overlaps
  exactly as it was shown: the window's live buffer, or the tile's own
  placeholder, laid out at the tile's size and only then scaled:
  - on press it is pushed in slightly, and its slot is left empty;
  - like a magnet, it stays stuck to the slot until the pointer has pulled it
    24 logical pixels, following only part of the pointer's travel;
  - past that it snaps off: it shrinks with a slight overshoot (to at most 75%
    of its size, and down to 35% for a screen-sized tile), rises, and then
    tracks the pointer exactly.
  The tile is scaled around the spot it was grabbed at, so that spot stays
  under the pointer throughout.
- A Super click that never lifts the tile is swallowed and changes nothing.
- In a workspace showing several tiles, the tiles show the layout the drop
  would produce, live:
  - over the workspace's row, the slot under the pointer is where the tile
    would land; the tiles slide aside to open a gap there, and the gap follows
    the pointer from slot to slot. Tiles are never swapped. Past the last
    tile, over the application launcher, the tile is appended;
  - the gap the tile left in its own workspace closes while it would land
    elsewhere;
  - with no target, the drop would put the tile back, so every tile slides
    back to its slot. Over its own slot, that is no target too.
- A workspace showing a single tile never moves its tiles while one is held:
  a gap would slide the shown tile away and leave the workspace empty. The
  half of the shown tile under the pointer picks the edge the held tile is
  inserted at (the left half before it, the right half after it), and a bar
  marks that edge. Over its own tile, either half is no target. Once the tile
  is released, the gap opens and the workspace scrolls to it, so the shown
  tile slides out (to the left when the tile lands after it, to the right
  when it lands before it) while the released tile lands in its place.
- Over a workspace button, the drop appends to that workspace, which lights
  up like a tab dragged over it. Its own workspace button is no target.
- Released, the tile flies into its gap or the shown slot (or into the
  workspace button, or back home) and lands flush. A workspace a released
  tile lands in scrolls its gap into view meanwhile. On the way, the tile
  reshapes to the size of the slot it lands in: its content is laid out at a
  size moving from its own to the slot's, so a placeholder reflows, while a
  window keeps its size anchored top-left, as the tile shows it until the
  client resizes. Flying into a workspace button, it only scales down. The drop is committed only once it
  lands: the tiles are laid out in their new order for one frame while the
  copy still covers the landing spot, then the copy disappears and the tile
  shows in its slot. A transfer keeps the copy at its landing spot until the
  destination lists the tile, since `insertWindow` is asynchronous.
- `Escape` or a cancelled pointer flies the tile back home. Releasing outside
  any target does the same.
- Releasing `Super` does not end the grab; only the mouse button does.

### Dropping

| Target | Same workspace | Another workspace |
| --- | --- | --- |
| Tile slot | reorder (`reorderWindowList`) | `insertWindow` at the slot |
| Workspace button | no-op | `insertWindow` at the end |

The dropped tile is selected in its workspace. The destination's
`insertWindow` owns a transfer, including its removal from the source
workspace.

### Navigating while holding

Keyboard focus stays on the screen the grab started from: Flutter keeps a held
pointer in its source view, so the destination screen never sees the pointer
enter. The shortcut manager therefore gives the grab the first look at every
bound intent while a tile is held:

| Intent | While a tile is held |
| --- | --- |
| `NavigateIntent` up/down | select the workspace above/below on the screen under the pointer |
| `NavigateIntent` left/right | select the tile left/right in that screen's selected workspace |
| `MoveIntent` | swallowed (it would fight the pointer) |
| `ToggleOverviewIntent` | swallowed (the overview would cover the drop targets) |

The drop target is re-resolved on every frame while a tile is held, since
navigation slides the layout under a pointer that does not move.

### Sliding tiles

The slot under the pointer comes from the row's geometry (its width over the
visible slot count, and its scroll offset), not from hit-testing the tiles:
tiles slide under the pointer as the gap moves, and hit-testing them would
make the target flip back and forth.

Each slot animates its absolute position in slots, not an offset from its
index. When the drop commits and a tile changes index, it is already shown
where it now belongs, so nothing moves. A keyboard reorder
(`Super+Shift+A/D`) slides the same way in a workspace showing several tiles;
one showing a single tile only slides its tiles to make room for a released
tile. The held tile's own hidden slot always jumps.

Tile slots are keyed by window, and `SlidingContainer` finds a keyed page by
its key, so a tile keeps its state (its window, focus and slide) when it is
reordered. While a tile is held, the workspace keeps a viewport's worth of
tiles built on each side, so a tile sliding in from off screen is already
there, and the selection border is hidden, since it marks a slot and not the
tile sliding through it.

### Super

The Super press that started a grab is a chord, not a sole press: its release
neither toggles the overview nor reaches the client as a lone Super tap (the
shell reports it handled, so the compositor drops the withheld press).

## Invariants

- A held tile is tracked by a global pointer route, never by the widget that
  started the grab: navigating can scroll the source workspace off its screen
  and unmount that widget.
- The client never receives a press that started a grab, nor its release.
- Only the screen under the pointer is navigated while a tile is held.
- A drop resolves against the destination's current window list, so the tile
  lands in the gap it was shown.
- The preview draws the window's texture only. A second `SurfaceWidget` would
  also report input and render origins for the surface.
