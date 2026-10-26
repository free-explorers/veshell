import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/window/widget/floating_window_stack.dart';

/// Renders a set of native windows as floating, positionable popups.
///
/// This is the tile's previous dialog presentation, kept for the windows the
/// client itself declares dialogs — a client parent, a modal hint, a fixed size
/// (see `isFloatingDialog`): stretching one of those into the tabbed panel
/// either distorts it or stretches it beyond its design, so it is shown at its
/// natural size over a dimmed tile instead.
class WindowDialogs extends StatelessWidget {
  const WindowDialogs({
    required this.metaWindowIds,
    this.maxSizeFactor = 1,
    super.key,
  });

  final List<MetaWindowId> metaWindowIds;

  /// Forwarded to each window to cap its size.
  final double maxSizeFactor;

  @override
  Widget build(BuildContext context) {
    return FloatingWindowStack(
      metaWindowIds: metaWindowIds,
      maxSizeFactor: maxSizeFactor,
      // The dialog overlay needs a shell frame for a bare surface;
      // floating-tile CSD windows render their own.
      frame: true,
    );
  }
}
