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
name, or the file name. Selecting a window's tab displays it and hands it the
keyboard. The content cross-fades when the selection changes, and only the
selected button is tinted — unselected buttons use a low surface.

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
overview is driven without leaving the home row. The bindings are the global
[`navigation.*`](navigation.md) ones; the overview context gives them their
meaning here, so there is no separate overview binding table:

| Key | Action |
|---|---|
| `Super+W` / `Super+S` | move the selection up / down in the current result list |
| `Super+A` / `Super+D` | move the keyboard focus left / right between the search pane and the content pane |
| `Enter` | activate the current result — the first one when nothing is selected |
| `Backspace` | go up to the parent directory (Files) |
| `Super+Tab` / `Super+Shift+Tab` | switch search mode: applications → files → settings |
| `Escape` | close the overview |

The search input keeps filtering while it has focus; the `Super`-modified keys
act on the current result list. Typing focuses the first result of the new list
once it is available — in Files mode that also opens its preview — so a search
can be accepted with `Enter` straight away. Clicking a result row focuses that
row; clicking the preview or the content pane leaves the search field focused.
The `Super` chords and `Escape` are handled
above both panes, so they act whichever part of the overview holds focus (the
search field, a content tab, a preview, or an embedded window); `Enter` is
bound and registered only by the search pane, so a focused client surface —
which is not a descendant of it — still receives it, and Flutter's
text-editing shortcuts cannot swallow `Enter` while the search field is focused.
The selection clamps at the first and last entry (no wrap). Because the overview
handles the standard navigation intents, these are the same global
`super+w/s/a/d` bindings, not shadowing copies (see
[Navigation and actions](navigation.md)).

The overview is a combobox: the search field keeps the keyboard while typing
and `Super+Down` (or a click) hands it to the result list; `Super+Up` on the
first result hands it back. The content pane — including the Helm — is made of
focusable Material widgets, so `Super+Left`/`Super+Right` move the keyboard
between the panes and the same direction keys then walk the Helm's controls,
switches and notification list. Focus drives the semantic focus, so the
selection is what assistive technology follows.

A displayed ephemeral window owns the keyboard: launching an application hands
focus to its surface as soon as it is mapped (the launch placeholder holds it
until then), and clicking the window or selecting its panel tab hands it back.
The surface's `SurfaceFocus` lets `Enter`, `Space`, `Escape`, `Tab` and the
direction keys fall through to the client, so they act in the application
instead of the overview — without the hand-off the search pane keeps the Flutter
focus and `Enter` would launch another instance. Use the `Super` chords to move
the keyboard back to the search pane to keep launching.

The navigation applies to all three modes: `Super+W`/`Super+S` move through the
mode's results and `Enter` activates them — a file opens with its handler, an
application is launched as an ephemeral window, and a settings row is activated.
With nothing selected, the **first** result is the one activated, so a search
can be accepted with `Enter` without moving the selection first. Activating a
file or application also resets the search. `Backspace` goes up to the parent
directory (Files only). Clicking an application selects and launches it
immediately.

In settings, the rows are walked as one visible list: a category header is
followed by its children, before the following category. While a filter is
active the category headers are only visual separators: they are skipped by the
selection and the keyboard, so the matches themselves are walked. `Enter` opens
or closes the selected category; on a setting it opens the editor with its input
focused, so the value can be typed immediately (an inline switch toggles in
place). `Enter` again — the framework's `ActivateIntent` — validates the input
and applies it, keeping the editor open with an inline error when the value
cannot be parsed. Dropdowns take the keyboard too: `Enter` opens the menu until
a choice is staged, then validates the staged choice; `Space` always opens the
menu.

## Properties

Layout currentLayout;  
List<[Tileable](tileable.md)> tileableList;  
