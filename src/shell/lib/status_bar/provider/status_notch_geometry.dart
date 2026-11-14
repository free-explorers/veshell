import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'status_notch_geometry.g.dart';

/// The laid-out size of the status notch of a screen, tracked by key once it
/// is painted. The workspace panels reserve room for it at the end of their
/// tile list, so the tiles scroll as soon as they would pass under it.
@riverpod
class StatusNotchSize extends _$StatusNotchSize {
  @override
  Size build(ScreenId screenId) => Size.zero;

  void set(Size size) {
    if (size != state) state = size;
  }
}

/// The width of what follows the tile list at the end of the workspace
/// panels of a screen (the visible tile picker and its margin). The status
/// notch is placed right before it.
@riverpod
class WorkspacePanelTrailingWidth extends _$WorkspacePanelTrailingWidth {
  @override
  double build(ScreenId screenId) => 0;

  void set(double width) {
    if (width != state) state = width;
  }
}
