# FileExplorer

## Description

The FileExplorer is the in-shell file browser shown by the overview's **Files**
search mode. It replaces the `FileSearchResult` placeholder with a deliberately
minimal browser: a **single list** of the current directory, with breadcrumbs
and an up action to move around, and a click to open.

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

## Navigation

- Clicking a directory enters it; the breadcrumb and up button move to
  ancestors (up is a no-op at `/`).
- The initial directory is `$HOME`.
- Symlinked directories are listed as directories and followed.
- A path that is missing, not a directory or unreadable puts the pane in an
  **error state** with the failing path and a retry, never a crash.

## Icons

A small `extension → glyph` map for the common cases (image, video, audio,
text, pdf, archive, code, executable); anything unknown gets a generic file
glyph. No MIME database, no themed-icon lookup.

## Opening entries

- A file entry is opened with the user's **default handler** by shelling out to
  `xdg-open <path>`, falling back to `gio open <path>` when `xdg-open` is not
  installed. Both resolve the handler through the desktop MIME database, so the
  choice matches the rest of the session.
- Once a launcher starts, the overview is dismissed so the launched window is
  visible, the same way navigating to a persistent tile dismisses it.
- The launched application is **not** attributed to a tile: it surfaces as an
  ordinary new window and the matching engine handles it like any other launch.
- No `open with` chooser.

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
- Thumbnails and content previews, archives, tags/ratings.
- Trash, removable volumes/device browsing, network shares, *Recent* — all the
  places where GIO (gvfs/`gio`) would be worth adding.
- Persisting the last path, view mode and sort order across shell restarts.

## Milestones

1. **M1 — list and navigate.** Module skeleton; `DirectoryPath` and
   `FileEntry`; `directoryListingProvider`; `FileExplorerState`; list rows with
   icons; breadcrumb + up; filter; error state. `FileSearchResult` is removed
   and `SearchEngine` renders the explorer.
2. **M2 — open.** Default-handler launch via `xdg-open`/`gio open`; loading,
   empty and error polish; keyboard navigation; tests.

Each milestone must pass `cargo check` (Rust + full Dart build),
`../.flutter_sdk/bin/flutter test` for new tests, and `cargo fmt`.
