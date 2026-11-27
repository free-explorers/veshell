import 'package:material_ui/material_ui.dart';

/// How much of a panel zen mode leaves in view: the selection line on its
/// inner edge.
const zenVisibleExtent = 2.0;

/// A panel that zen mode slides out of its screen.
///
/// Collapsed, it keeps only [visibleExtent] of its inner edge, [alignment]
/// side, in view: the selection line still shows which workspace or tile is
/// selected, and the space the panel gave up goes to the content beside it.
/// The panel keeps its full layout while it slides, clipped, so it moves out
/// rather than squeezing.
class ZenCollapse extends StatelessWidget {
  const ZenCollapse({
    required this.collapsed,
    required this.axis,
    required this.extent,
    required this.alignment,
    required this.child,
    this.visibleExtent = zenVisibleExtent,
    super.key,
  });

  /// Whether the panel is slid out.
  final bool collapsed;

  /// The axis it slides along: horizontal for a side panel, vertical for a
  /// top one.
  final Axis axis;

  /// The panel's full size along [axis].
  final double extent;

  /// The edge left in view, where the selection line is drawn.
  final Alignment alignment;

  /// How much of the panel stays in view when collapsed; 0 for a panel
  /// without a selection line, which slides out entirely.
  final double visibleExtent;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final collapsedFactor = visibleExtent / extent;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: collapsed ? collapsedFactor : 1),
      duration: Durations.medium2,
      curve: Curves.easeInOutCubic,
      builder: (context, factor, child) => ClipRect(
        child: Align(
          alignment: alignment,
          widthFactor: axis == Axis.horizontal ? factor : null,
          heightFactor: axis == Axis.vertical ? factor : null,
          child: child,
        ),
      ),
      // Out of reach while slid out: only its selection line shows.
      child: IgnorePointer(
        ignoring: collapsed,
        child: ExcludeFocus(excluding: collapsed, child: child),
      ),
    );
  }
}
