# WorkspacePanel

## Description

a panel used to represent the current state of a [Screen](screen.md) displaying the list of workspace

## Workspace icons

Each workspace button shows an icon chosen by the `theme.workspaceIcon`
setting:

- `hybrid` (the default): the application's icon when the workspace holds a
  single application, whatever its number of windows; the workspace
  category's icon otherwise. Several applications with no recognised category
  share the button as in `application`.
- `category`: always the workspace category's icon; `System` when the
  category is unknown.
- `application`: always the applications' icons. The button is split between
  the up to four most present applications (most windows first, ties in order
  of appearance): the left and right halves for two, three wedges of a disc
  for three (the first on top), the quarters for four, in reading order. Each
  icon is drawn at full size and shows only the part of itself that falls in
  its share, with a thin gap between shares.

An empty workspace shows `+`.

A workspace can have a fixed category: right-click (or long-press) its button,
then pick a category under **Workspace icon**. A fixed category is shown in
every mode, even on an empty workspace, and is kept with the workspace;
**Automatic** releases it and detects the category from the windows again.
