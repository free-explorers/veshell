import 'package:collection/collection.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/meta_window/provider/meta_window_resizing_state.dart';
import 'package:shell/platform/model/event/interactive_resize/interactive_resize.serializable.dart';

class WithResizeHandles extends StatelessWidget {
  const WithResizeHandles({
    required this.metaWindowId,
    required this.child,
    super.key,
    this.borderWidth = 10,
    this.cornerWidth = 18,
    this.onResizeStart,
  });
  final String metaWindowId;
  final Widget child;
  final double borderWidth;
  final double cornerWidth;

  /// Called on pointer down on a resize handle. When set, the compositor owns
  /// the resize; otherwise the handle uses the historical Flutter-local resize.
  final ValueChanged<ResizeEdge>? onResizeStart;

  @override
  Widget build(BuildContext context) {
    final handles = _buildResizeHandles();
    return DeferredPointerHandler(
      child: Stack(
        clipBehavior: Clip.none,
        // Handles paint above the surface, so their edges win hit-testing.
        children: [...handles, child],
      ),
    );
  }

  List<Widget> _buildResizeHandles() {
    final inset = -borderWidth;
    final edgeInset = cornerWidth - borderWidth;
    Widget handle(ResizeEdge edge) => ResizeHandle(
      metaWindowId: metaWindowId,
      resizeEdge: edge,
      onResizeStart: onResizeStart,
    );
    return ResizeEdge.values.whereNot((e) => e == ResizeEdge.none).map((e) {
      return switch (e) {
        ResizeEdge.topLeft => Positioned(
          top: inset,
          left: inset,
          child: SizedBox(
            width: cornerWidth,
            height: cornerWidth,
            child: handle(e),
          ),
        ),
        ResizeEdge.top => Positioned(
          top: inset,
          left: edgeInset,
          right: edgeInset,
          child: SizedBox(height: borderWidth, child: handle(e)),
        ),
        ResizeEdge.topRight => Positioned(
          top: inset,
          right: inset,
          child: SizedBox(
            width: cornerWidth,
            height: cornerWidth,
            child: handle(e),
          ),
        ),
        ResizeEdge.right => Positioned(
          top: edgeInset,
          right: inset,
          bottom: edgeInset,
          child: SizedBox(width: borderWidth, child: handle(e)),
        ),
        ResizeEdge.bottomRight => Positioned(
          bottom: inset,
          right: inset,
          child: SizedBox(
            width: cornerWidth,
            height: cornerWidth,
            child: handle(e),
          ),
        ),
        ResizeEdge.bottom => Positioned(
          bottom: inset,
          left: edgeInset,
          right: edgeInset,
          child: SizedBox(height: borderWidth, child: handle(e)),
        ),
        ResizeEdge.bottomLeft => Positioned(
          bottom: inset,
          left: inset,
          child: SizedBox(
            width: cornerWidth,
            height: cornerWidth,
            child: handle(e),
          ),
        ),
        ResizeEdge.left => Positioned(
          top: edgeInset,
          left: inset,
          bottom: edgeInset,
          child: SizedBox(width: borderWidth, child: handle(e)),
        ),

        // This case must be filtered out
        ResizeEdge.none => throw UnimplementedError(),
      };
    }).toList();
  }
}

class ResizeHandle extends ConsumerWidget {
  const ResizeHandle({
    required this.metaWindowId,
    required this.resizeEdge,
    super.key,
    this.onResizeStart,
  });
  final String metaWindowId;
  final ResizeEdge resizeEdge;
  final ValueChanged<ResizeEdge>? onResizeStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handle = MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      cursor: _getMouseCursor(),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) {
          final start = onResizeStart;
          if (start != null) {
            start(resizeEdge);
            return;
          }
          ref
              .read(metaWindowResizingStateProvider(metaWindowId).notifier)
              .startResizing(resizeEdge);
        },
      ),
    );
    // The deferred handler hit-tests the handle beyond the window box, so an
    // exact-size `Positioned` window still has reachable outer edges.
    return DeferPointer(child: handle);
  }

  MouseCursor _getMouseCursor() {
    switch (resizeEdge) {
      case ResizeEdge.topLeft:
        return SystemMouseCursors.resizeUpLeft;
      case ResizeEdge.top:
        return SystemMouseCursors.resizeUp;
      case ResizeEdge.topRight:
        return SystemMouseCursors.resizeUpRight;
      case ResizeEdge.right:
        return SystemMouseCursors.resizeRight;
      case ResizeEdge.bottomRight:
        return SystemMouseCursors.resizeDownRight;
      case ResizeEdge.bottom:
        return SystemMouseCursors.resizeDown;
      case ResizeEdge.bottomLeft:
        return SystemMouseCursors.resizeDownLeft;
      case ResizeEdge.left:
        return SystemMouseCursors.resizeLeft;
      case ResizeEdge.none:
        return SystemMouseCursors.basic;
    }
  }
}
