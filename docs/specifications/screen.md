# Screen

## Description

a Screen represent a portion of a Monitor where we want to render Veshell. Monitor usually contain a single Screen but for ultra-wide monitor it could be usefull to be able to split it in several Screen.

## Properties

int x;  
int y;  
int width;  
int height;  
List<[Workspace](workspace.md)> workspaceList;

## Focused screen

`focusedScreenProvider` holds the screen that currently owns focus, or `null`
while no screen exists. It is reconciled against `screenManager`'s live screen
set:

- A still-valid focused screen is preserved when other screens are created or
  removed.
- If the focused screen is deleted, `ScreenManager.removeScreen` moves focus to
  the first remaining screen before deleting it; if none remain the value is
  `null`.
- The value never points at a deleted screen and never throws.

Readers treat `null` as "nothing focused": a new window is left unplaced rather
than routed into a missing screen, notifications are not surfaced, and
`focusedMonitor` falls back to the first connected monitor.
