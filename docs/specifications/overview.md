# Overview

## Description

The overview provide the quick app launcher to launch and display ephemeral window

The overview's content panel behaves like a tab bar selecting what is shown in
the content region. The panel is the **Helm** dashboard followed by
`Overview.contentList` — ephemeral windows and file previews, as peers in
creation order. The sealed `OverviewContent` union defines the kinds
(`helm`, `window`, `preview`); adding a kind is a compile error until the
content body and the tab builders handle it. `selectedContentId` names the
displayed content and `Overview.selectedContent` resolves it (falling back to
the Helm when stale). Opening the overview keeps the current selection and
`show(windowId)` opens it to a specific window (used when bringing a window into
view). Each tab shows its icon and a label — `Helm`, the window's application
name, or the file name. The content cross-fades when the selection changes, and
only the selected button is tinted — unselected buttons use a low surface.

Selecting a file in the Files mode opens or reuses a **preview tab** and
displays it:

- while a preview is selected, selecting another file replaces that tab's
  content in place (the tab keeps its identity);
- otherwise an existing tab for the file's path is selected, or a new preview
  tab is appended to the list.

Previews persist until their close button is used — clearing the row selection,
changing the filter or the mode, or switching to another tab leaves them open.
Closing a content selects its neighbour, or the Helm when the list is empty.

Its search engine offers three modes: applications, files and settings. The
**files** mode is the [FileExplorer](file_explorer.md), an in-shell file
browser replacing the former placeholder.

## Keyboard

Veshell favours left-hand shortcuts. While the overview is open, navigation
reuses the `Super`+WASD family already used for workspaces and tiles, so the
overview is driven without leaving the home row:

| Key | Action |
|---|---|
| `Super+W` / `Super+S` | move the selection up / down in the current result list |
| `Super+D` | open the selected entry — a folder is entered, a file/application is activated |
| `Super+A` | go up to the parent directory (breadcrumb up) |
| `Super+Tab` / `Super+Shift+Tab` | switch search mode: applications → files → settings |

The search input keeps filtering while it has focus; the `Super`-modified keys
act on the current result list. Clicking elsewhere in the overview (a result
row, the preview) keeps the search focused, so the shortcuts keep working after
a mouse selection. The selection clamps at the first and last entry (no wrap).
While the overview is open these shadow the global `super+w/s/a/d`
workspace/tileable hotkeys.

The navigation applies to all three modes: `Super+W`/`Super+S` move through the
mode's results and `Super+D` (or `Enter`) activates them — a file opens with its
handler, an application is launched as an ephemeral window, and a settings row
is activated. Activating a file or application also resets the search;
`Super+A` (parent directory) is files-only. Clicking an application selects and
launches it immediately.

In settings, the rows are walked as one visible list: an opened category's
children come next, before the following category. `Super+D` opens or closes the
selected category; leaf settings have nothing to activate.

## Properties

Layout currentLayout;  
List<[Tileable](tileable.md)> tileableList;  
