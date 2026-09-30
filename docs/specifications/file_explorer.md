# FileExplorer

## Description

The FileExplorer is the in-shell file browser shown by the overview's **Files**
search mode. It replaces the `FileSearchResult` placeholder with a deliberately
minimal browser: a **single list** of the current directory, with breadcrumbs
and an up action to move around. A single click **selects** an entry (driving
the in-overview preview) and a double click or `Enter` **opens** it.

It lives entirely in the Dart shell and uses only `dart:io` for directory
enumeration. No Rust, no platform-channel work, and **no GIO dependency**: the
compositor is uninvolved, and GIO's value (trash, removable volumes, network
shares, accurate MIME) is all out of scope for a plain local listing.

## Placement

- New module `src/shell/lib/file_explorer/` with `model/`, `provider/` and
  `widget/` subdirectories.
- `SearchEngine`'s `SearchMode.file` branch renders `FileExplorerView` instead
  of `FileSearchResult`; the placeholder widget is deleted.
- The pane reuses the overview's `SearchInput`. In file mode the typed text is
  a **live filter of the current directory** (case-insensitive name match over
  every entry, directories included), not a global file search.

## Layout

A single scrollable list inside the same card as the other search modes.

- A header row with the **breadcrumb** of the current path and an **up** button.
- The **listing**: one row per entry with an icon and the name. Directories
  sort before files, then alphabetically. Directories show a folder glyph; files
  show a glyph picked from a small extension→icon table, with a generic file
  glyph as fallback.
- The **selected** row is highlighted; the selection is the preview target shown
  in the `OverviewContent` slot (see
  [`design/file_preview.md`](../design/file_preview.md)).

There is no locations column, no grid, no sort menu and no properties pane.

## Model

`FileExplorerState` (Freezed) describes the pane:

- `DirectoryPath path` — the directory currently listed.
- `String filterText` — the live filter from the shared search input.
- `bool isShowingHidden` — default **true**: dotfiles are listed. There is no
  toggle in the minimal version; surfacing it as an option comes later.

`FileEntry` is the immutable row model:

- `String name`, `DirectoryPath path`;
- `bool isDirectory`;
- `int size` (files only; sentinel for directories).

`DirectoryPath` is the shell's path value type (normalised absolute path) so
providers can be keyed by it and equality works.

## State and providers

- `fileExplorerStateProvider` — the pane's state (Notifier), keyed by
  `ScreenId` because the overview is per screen.
- `directoryListingProvider(DirectoryPath)` — async family that enumerates one
  directory; `autoDispose`, cancelled on navigation.
- `filteredEntryListProvider` — derived list applying `filterText` and
  `isShowingHidden`, with directories first.
- **Selection** is not held by the pane: it lives on the screen's `Overview`
  (`selectedPath`), so `OverviewContent` can read it to render the preview. The
  pane writes it on click and on keyboard navigation, and clears it when it is
  left.
- The pane keeps a **navigation history** of visited directories so `Super+A`
  can walk back. Forward history is not bound yet.

## Navigation and selection

- A single click **selects** any entry; a double click **opens** it — a
  directory is entered, a file goes to its handler.
- `Super+W`/`Super+S` move the selection over the current filtered, sorted list
  and scroll it into view; `Super+D` opens the selected entry (see the
  overview's [keyboard contract](overview.md#keyboard)).
- `Super+A` walks back through the pane's directory history.
- The breadcrumb and up button move to ancestors (up is a no-op at `/`); the
  initial directory is `$HOME`.
- Symlinked directories are listed as directories and followed.
- A path that is missing, not a directory or unreadable puts the pane in an
  **error state** with the failing path and a retry, never a crash.

## Icons

A small `extension → glyph` map for the common cases (image, video, audio,
text, pdf, archive, code, executable); anything unknown gets a generic file
glyph. No MIME database, no themed-icon lookup.

## Opening entries

- Opening is triggered by a **double click**, `Enter`, or `Super+D` on the
  selected row; a single click only selects and previews.
- A file entry is opened with the user's **default handler** by shelling out to
  `xdg-open <path>`, falling back to `gio open <path>` when `xdg-open` is not
  installed. Both resolve the handler through the desktop MIME database, so the
  choice matches the rest of the session.
- A directory entry is opened by entering it.
- Once a launcher starts, the overview is dismissed so the launched window is
  visible, the same way navigating to a persistent tile dismisses it.
- The launched application is **not** attributed to a tile: it surfaces as an
  ordinary new window and the matching engine handles it like any other launch.
- No `open with` chooser.

> Launching the handler **as an ephemeral window** instead of a workspace tile
> is explored in
> [`design/file_explorer_ephemeral_launch.md`](../design/file_explorer_ephemeral_launch.md).

## Performance and refresh

- Enumeration consumes `Directory.list` asynchronously and fills the list
  progressively; very large directories must not block the shell's frame.
- No filesystem watcher. The listing refreshes when a directory is (re)entered.

## Out of scope (future milestones)

- **Mutations**: create folder/file, rename, delete, copy, move, move-to-trash,
  undo.
- **Recursive search** — the original intent of the file search mode; the
  filter only narrows the current directory.
- Locations column, grid view, sort menu, size/modified columns.
- `open with` chooser, running `.desktop` files, a *Properties* dialog.
- Multi-selection, drag & drop, clipboard, share/export.
- Thumbnails and content previews, archives, tags/ratings (previews are
  explored in [`design/file_preview.md`](../design/file_preview.md)).
- Trash, removable volumes/device browsing, network shares, *Recent* — all the
  places where GIO (gvfs/`gio`) would be worth adding.
- Persisting the last path, view mode and sort order across shell restarts.

## Milestones

1. **M1 — list and navigate.** Module skeleton; `DirectoryPath` and
   `FileEntry`; `directoryListingProvider`; `FileExplorerState`; list rows with
   icons; breadcrumb + up; filter; error state. `FileSearchResult` is removed
   and `SearchEngine` renders the explorer.
2. **M2 — select and open.** Selection model (single click selects/previews,
   double click or `Enter` opens); default-handler launch via
   `xdg-open`/`gio open`; keyboard navigation; loading, empty and error polish;
   tests.

> **Status:** M1 and M2 landed with click-to-open (a click navigated or opened).
> The selection model above supersedes that and is not yet implemented; the
> preview slot itself is still to be built
> ([`design/file_preview.md`](../design/file_preview.md)).

Each milestone must pass `cargo check` (Rust + full Dart build),
`../.flutter_sdk/bin/flutter test` for new tests, and `cargo fmt`.
