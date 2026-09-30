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

Veshell favours left-hand shortcuts; the overview is driven without leaving the
home row.

| Key | Action |
|---|---|
| `Tab` / `Shift+Tab` | move the selection down / up in the current result list |
| `Space` / `Enter` | open (activate) the selected result |
| `Super+Tab` / `Super+Shift+Tab` | switch search mode: applications → files → settings |

The search input filters while it has focus. The first `Tab` moves from the input
into the result list; typing a printable character returns to the input so
filtering stays continuous. Because `Space` activates, it only does so while the
result list is focused — in the input it still types a space.

## Properties

Layout currentLayout;  
List<[Tileable](tileable.md)> tileableList;  
