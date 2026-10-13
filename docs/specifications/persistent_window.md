# TileableWindow

## Description

a TileableWindow is a [Tileable](tileable.md) that represent an application window that persist in the layout even when it's closed.

## Launch lifecycle

A launch runs the application through `AppLaunch` in a tracked
`veshell-launch-<tile-uuid>-*.service` unit. Removing the tile while the launch
has not produced a native window cancels that unit (`systemctl --user stop`,
i.e. SIGTERM to the cgroup); once a window is displayed the tile is no longer
pending and the application exits by closing its window. A launch whose process
is already showing a window under another tile is left running.

## Properties

WindowState state; // placeholder or opened  
List<[Window]()> modalList;  
