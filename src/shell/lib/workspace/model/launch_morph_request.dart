import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show LayerLink;
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';

/// Where a launch starts: the launcher item, its icon and its label, in
/// global coordinates, and the `section` of the launcher it was in (as the
/// launcher names its sections), where a new item replaces the one that left.
typedef LaunchOrigin = ({
  ui.Rect item,
  ui.Rect icon,
  ui.Rect label,
  Object? section,
});

/// A launch from the tiled launcher, for the new tile to open with: its item
/// morphs into the tile's placeholder (see `LaunchMorph`).
class LaunchMorphRequest {
  LaunchMorphRequest({
    required this.entry,
    required this.origin,
    required this.launcherRect,
  });

  final LocalizedDesktopEntry entry;

  final LaunchOrigin origin;

  /// Where the launcher was, in global coordinates: the new tile takes its
  /// place.
  final ui.Rect launcherRect;

  /// Links the morph, drawn above the workspace's tile row, to the tile: the
  /// launcher slides aside under it (later slots paint over earlier ones, so
  /// drawn in the tile it would be covered).
  final LayerLink link = LayerLink();
}
