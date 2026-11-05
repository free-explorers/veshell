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

- A header row with an **up** button, the **breadcrumb** and the **view
  options** button (top right).
  - The breadcrumb sits on a rounded track: the path segments as clickable
    labels separated by chevrons, the current segment emphasised, scrolling
    horizontally from the current directory. A path inside `$HOME` starts at a
    **Home** crumb instead of spelling out `/home/<user>`; any other path starts
    at a `/` crumb.
  - The view options menu edits the [preferences](#view-options) in place; the
    menu stays open while toggling so several options can be changed at once.
- The **listing**: one full-width row per entry. Each row shows a type glyph
  in the type's accent colour (folders use the theme's primary colour), the
  name, and — when details are on — a second line
  with the size of a file or the item count of a folder (`Empty`, `1 item`,
  `12 items`; dotfiles counted only when hidden files are shown, and counted
  lazily for the rows on screen), then the modification date (time for today, day
  and month this year, full date otherwise). Folders end with a chevron.
  Hidden entries are drawn faded.
- The **selected** row is a full-width `primaryContainer` fill; selecting an entry
  opens it in the overview's preview tab (see
  [`design/file_preview.md`](../design/file_preview.md)).

There is no locations column, no grid and no properties pane.

## View options

Persisted in `settings.json` under `files` (the shell Settings list them under
**Files** too) and shared by the overview's Files pane and the portal file
chooser:

| Key | Default | Meaning |
| --- | --- | --- |
| `showHidden` | `false` | List dotfiles. |
| `sortBy` | `name` | `name` (natural, case-insensitive: `file2` before `file10`), `modified`, `size` (folders keep their name order) or `type` (broad type, then extension). Ties fall back to the name. |
| `sortDescending` | `false` | Reverse the order. |
| `foldersFirst` | `true` | Folders before files whatever the sort; reversing applies within each group. |
| `showDetails` | `false` | Two-line rows with size/type and date; off gives the regular one-line rows. |

## Model

`FileExplorerState` (Freezed) describes the pane:

- `DirectoryPath path` — the directory currently listed.
- `String filterText` — the live filter from the shared search input.
- `List<String> typePatternList` — the portal chooser's type filter: globs
  (`*.png`, matched case-insensitively on the whole name) or MIME types
  (`image/*`, `image/png`, approximated from the extension; an unknown MIME
  type filters nothing). Empty lists every file; folders always pass.
- `bool isDirectoryOnly` — list folders only (the portal's folder picker).

The hidden-files flag is a [view option](#view-options), not pane state.

`FileEntry` is the immutable row model:

- `String name`, `DirectoryPath path`;
- `bool isDirectory`;
- `int size` (files only; sentinel for directories);
- `DateTime? modified`.

`DirectoryPath` is the shell's path value type (normalised absolute path) so
providers can be keyed by it and equality works.

## State and providers

- `fileExplorerStateProvider` — the pane's state (Notifier), keyed by
  `ScreenId` because the overview is per screen.
- `directoryListingProvider(DirectoryPath)` — async family that enumerates one
  directory; `autoDispose`, cancelled on navigation.
- `fileExplorerSettingsProvider` — the persisted [view options](#view-options).
- `filteredEntryListProvider` — derived list applying `filterText`, the type
  filter and the view options.
- **Selection** is not held by the pane: it lives on the screen's `Overview` as
  `selectedIndex`, an index into the active mode's result list. The pane is
  presentational — it receives `selectedIndex` and click/keyboard callbacks —
  and `OverviewContent` maps the index back to the file path for the preview.
  A change to the filter focuses the first entry (opening its preview); a
  change of the search mode clears the selection.

## Navigation and selection

- A single click **selects** any entry; a double click **opens** it — a
  directory is entered, a file goes to its handler.
- `Super+W`/`Super+S` move the selection over the current filtered, sorted list
  and scroll it into view, clamping at the first and last entry (no wrap);
  `Super+D` activates the selected entry (see the overview's
  [keyboard contract](overview.md#keyboard)).
- `Super+A` goes up to the parent directory, the same action as the breadcrumb
  and the up button (a no-op at `/`).
- The breadcrumb is laid out from the left, right after the up button, and
  scrolls so the current directory stays visible when the path is too long to
  fit.
- Going up, or jumping to an ancestor from the breadcrumb, **pre-selects the
  directory you came from** once the parent listing loads.
- Entering a directory (double click, `Super+D`/`Enter`) **selects its first
  entry** once the new listing loads, so the preview and the keyboard are ready
  to move on immediately (an empty directory selects nothing).
- Activating an entry with `Super+D`/`Enter` also clears the filter, so the new
  directory is shown unfiltered. With nothing selected, the first entry is the
  one activated.
- The initial directory is `$HOME`.
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
- Locations column, grid view.
- `open with` chooser, running `.desktop` files, a *Properties* dialog.
- Multi-selection, drag & drop, clipboard, share/export.
- Thumbnails and content previews, archives, tags/ratings (previews are
  explored in [`design/file_preview.md`](../design/file_preview.md)).
- Trash, removable volumes/device browsing, network shares, *Recent* — all the
  places where GIO (gvfs/`gio`) would be worth adding.
- Persisting the last path across shell restarts.

## Milestones

1. **M1 — list and navigate.** Module skeleton; `DirectoryPath` and
   `FileEntry`; `directoryListingProvider`; `FileExplorerState`; list rows with
   icons; breadcrumb + up; filter; error state. `FileSearchResult` is removed
   and `SearchEngine` renders the explorer. *(landed)*
2. **M2 — open.** Default-handler launch via `xdg-open`/`gio open`. *(landed)*
3. **M3 — selection, keyboard and preview.** Single click selects and previews,
   double click or `Super+D` activates, `Super+W`/`Super+S` move the selection
   (clamped), `Super+A` goes to the parent directory, `Super+Tab` switches the
   search mode; the `OverviewContent` slot renders the preview
   ([`design/file_preview.md`](../design/file_preview.md)) for the phase-1 types
   (text, raster image, SVG, binary hex, metadata fallback). *(landed)*

4. **M4 — view options and readability.** The persisted view options menu
   (hidden files, sort key and direction, folders first, details), coloured
   type glyphs, two-line rows and the Home breadcrumb. *(landed)*

> **Status:** M1–M4 landed, and the selection/keyboard layer now covers the
> application, file and settings modes. Still to build: the preview's external
> backends (PDF via poppler, video poster / audio metadata via ffmpeg, office,
> archives, playback).

Each milestone must pass `cargo check` (Rust + full Dart build),
`../.flutter_sdk/bin/flutter test` for new tests, and `cargo fmt`.

## Portal file chooser

The trusted FileChooser dialog (`file_chooser/`) embeds the same explorer with
its own browse state.

- **It takes the keyboard on open.** The hosting tile keeps its own focus node
  focused, so the dialog requests focus explicitly rather than relying on
  `autofocus`: a save dialog focuses the file name with the base name selected
  (`report` in `report.pdf`), ready to be retyped; the other modes focus the
  search field. A click inside the chooser keeps the keyboard there, and the
  tile's window gets it back when the chooser closes.
- The search field filters the current folder live; `↑`/`↓` move the selection
  and `Enter` opens the selected (or first) entry. Entering a folder clears the
  search. In a save dialog, picking a file copies its name to the name field
  and `Enter` in that field saves.
- The application's filters are offered in a type menu next to the search,
  the **first filter applied by default**, then *All files*. They filter the
  listing through `typePatternList`, independently of the search text.
- The folder picker lists folders only and returns the selected folder, or the
  current one when none is selected.
- The selection is tracked by path, so filtering or re-sorting never moves it
  onto another entry.
