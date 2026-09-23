import 'package:flutter/material.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/shared/widget/container_with_positionnable_children/container_with_positionnable_children.dart';
import 'package:shell/window/widget/floatable_window.dart';

/// Renders a set of native windows as floating, positionable popups.
///
/// Extracted from `WindowWidget` so a tile can render the dialogs attached to
/// it even when it has no main meta window yet (in which case they are its only
/// content). [ContainerWithPositionnableChildren] provides the
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
          ),
      ],
    );
  }
}
