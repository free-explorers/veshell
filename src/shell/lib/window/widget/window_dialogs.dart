import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/shared/widget/container_with_positionnable_children/container_with_positionnable_children.dart';
import 'package:shell/window/widget/floatable_window.dart';

/// Renders a set of native windows as floating, positionable popups.
///
/// This is the tile's previous dialog presentation, kept for the dialogs a
/// stretched, tabbed panel does not suit: a modal or fixed-size surface is
/// shown at its natural size over a dimmed tile instead of being tiled.
/// [ContainerWithPositionnableChildren] provides the
/// `RepositionnableControllerWidget` that [FloatableWindow] relies on.
class WindowDialogs extends StatelessWidget {
  const WindowDialogs({
    required this.metaWindowIds,
    this.maxSizeFactor = 1,
    super.key,
  });

  final List<MetaWindowId> metaWindowIds;

  /// Forwarded to each [FloatableWindow] to cap its size.
  final double maxSizeFactor;

  @override
  Widget build(BuildContext context) {
    if (metaWindowIds.isEmpty) {
      return const SizedBox.shrink();
    }
    return ContainerWithPositionnableChildren(
      children: [
        for (final metaWindowId in metaWindowIds)
          FloatableWindow(
            metaWindowId: metaWindowId,
            maxSizeFactor: maxSizeFactor,
            // Modal and fixed-size dialogs get the shell frame, so one with no
            // decoration of its own does not read as a flat rectangle.
            frame: true,
          ),
      ],
    );
  }
}
