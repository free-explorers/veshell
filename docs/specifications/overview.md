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

## Properties

Layout currentLayout;  
List<[Tileable](tileable.md)> tileableList;  
