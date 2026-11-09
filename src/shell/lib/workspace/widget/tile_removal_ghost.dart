import 'package:material_ui/material_ui.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/workspace/widget/tile_face.dart';

/// The face of a tile removed from a workspace, left in the slot it occupied
/// until the tile sliding into it has covered it (see `TileDropSlot.leaving`).
///
/// It only draws the tile's face: the real tile is already gone, and with it
/// its window, focus and input handling.
class TileRemovalGhost extends StatelessWidget {
  const TileRemovalGhost({
    required this.window,
    required this.focused,
    super.key,
  });

  /// The removed tile's last state.
  final PersistentWindow window;

  /// Whether it had the selected placeholder look.
  final bool focused;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => TileFace(
          window: window,
          layoutSize: constraints.biggest,
          windowSize: constraints.biggest,
          focused: focused,
        ),
      ),
    ),
  );
}
