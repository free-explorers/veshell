# Overview

## Description

The overview provide the quick app launcher to launch and display ephemeral window

The overview shows one ephemeral window at a time: `focusedWindowId` when it is
set, otherwise the first of `windowList`. Opening the overview keeps the current
selection; `show(windowId)` opens it to a specific window (used when bringing a
window into view), and the panel buttons switch the displayed window.

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
act on the current result list. While the overview is open these shadow the
global `super+w/s/a/d` workspace/tileable hotkeys.

## Properties

Layout currentLayout;  
List<[Tileable](tileable.md)> tileableList;  
