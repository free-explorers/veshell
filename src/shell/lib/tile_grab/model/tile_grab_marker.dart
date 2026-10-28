import 'package:shell/screen/model/screen.serializable.dart';
import 'package:shell/workspace/provider/workspace_state.dart';

/// `MetaData` a held tile looks for under the pointer. Markers are found by
/// hit-testing, so they also resolve on another monitor's view.
sealed class TileGrabMarker {
  const TileGrabMarker();
}

/// The row of tile slots of a workspace, as wide as [visible] slots.
///
/// The slot under the pointer is found from the row's geometry, not by
/// hit-testing the tiles: tiles slide aside while a tile is held, and one
/// sliding under the pointer would move the target back and forth.
class TileRowMarker extends TileGrabMarker {
  const TileRowMarker({
    required this.workspaceId,
    required this.visible,
    required this.scrollOffset,
  });
  final WorkspaceId workspaceId;
  final int visible;

  /// The row's current scroll offset along its axis.
  final double Function() scrollOffset;
}

/// A workspace button in the screen panel.
class TileWorkspaceButtonMarker extends TileGrabMarker {
  const TileWorkspaceButtonMarker(this.workspaceId);
  final WorkspaceId workspaceId;
}

/// A screen: navigation keys act on the screen under the held tile.
class TileGrabScreenMarker extends TileGrabMarker {
  const TileGrabScreenMarker(this.screenId);
  final ScreenId screenId;
}
