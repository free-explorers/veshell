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
    this.inside = false,
    this.onResizeStart,
  });
  final String metaWindowId;
  final Widget child;
  final double borderWidth;
  final double cornerWidth;

  /// Place the handles inside the child bounds instead of around them.
  ///
  /// The default outside placement relies on `DeferPointer`: a
  /// `DeferredPointerHandler` hit-tests registered handles even when they lie
  /// outside its own box, so exact-size `Positioned` windows can still be
  /// resized from their outer edge.
  final bool inside;

  /// Called on pointer down on a resize handle. When set, the compositor owns
  /// the resize; otherwise the handle uses the historical Flutter-local resize.
  final ValueChanged<ResizeEdge>? onResizeStart;

  @override
  Widget build(BuildContext context) {
    final handles = _buildResizeHandles();
    return DeferredPointerHandler(
      child: Stack(
        clipBehavior: Clip.none,
        // Handles must be after the surface in paint/hit-test order when they
        // are inside, otherwise the client surface consumes their edges.
        children: inside ? [child, ...handles] : [...handles, child],
      ),
    );
  }

  List<Widget> _buildResizeHandles() {
    final inset = inside ? 0.0 : -borderWidth;
    final edgeInset = inside ? cornerWidth : cornerWidth - borderWidth;
    return ResizeEdge.values.whereNot((e) => e == ResizeEdge.none).map((e) {
      return switch (e) {
        ResizeEdge.topLeft => Positioned(
          top: inset,
          left: inset,
          child: SizedBox(
            width: cornerWidth,
            height: cornerWidth,
            child: ResizeHandle(
              metaWindowId: metaWindowId,
              resizeEdge: e,
              inside: inside,
              onResizeStart: onResizeStart,
            ),
          ),
        ),
        ResizeEdge.top => Positioned(
          top: inset,
          left: edgeInset,
          right: edgeInset,
          child: SizedBox(
            height: borderWidth,
            child: ResizeHandle(
              metaWindowId: metaWindowId,
              resizeEdge: e,
              inside: inside,
              onResizeStart: onResizeStart,
            ),
          ),
        ),
        ResizeEdge.topRight => Positioned(
          top: inset,
          right: inset,
          child: SizedBox(
            width: cornerWidth,
            height: cornerWidth,
            child: ResizeHandle(
              metaWindowId: metaWindowId,
              resizeEdge: e,
              inside: inside,
              onResizeStart: onResizeStart,
            ),
          ),
        ),
        ResizeEdge.right => Positioned(
          top: edgeInset,
          right: inset,
          bottom: edgeInset,
          child: SizedBox(
            width: borderWidth,
            child: ResizeHandle(
              metaWindowId: metaWindowId,
              resizeEdge: e,
              inside: inside,
              onResizeStart: onResizeStart,
            ),
          ),
        ),
        ResizeEdge.bottomRight => Positioned(
          bottom: inset,
          right: inset,
          child: SizedBox(
            width: cornerWidth,
            height: cornerWidth,
            child: ResizeHandle(
              metaWindowId: metaWindowId,
              resizeEdge: e,
              inside: inside,
              onResizeStart: onResizeStart,
            ),
          ),
        ),
        ResizeEdge.bottom => Positioned(
          bottom: inset,
          left: edgeInset,
          right: edgeInset,
          child: SizedBox(
            height: borderWidth,
            child: ResizeHandle(
              metaWindowId: metaWindowId,
              resizeEdge: e,
              inside: inside,
              onResizeStart: onResizeStart,
            ),
          ),
        ),
        ResizeEdge.bottomLeft => Positioned(
          bottom: inset,
          left: inset,
          child: SizedBox(
            width: cornerWidth,
            height: cornerWidth,
            child: ResizeHandle(
              metaWindowId: metaWindowId,
              resizeEdge: e,
              inside: inside,
              onResizeStart: onResizeStart,
            ),
          ),
        ),
        ResizeEdge.left => Positioned(
          top: edgeInset,
          left: inset,
          bottom: edgeInset,
          child: SizedBox(
            width: borderWidth,
            child: ResizeHandle(
              metaWindowId: metaWindowId,
              resizeEdge: e,
              inside: inside,
              onResizeStart: onResizeStart,
            ),
          ),
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
    this.inside = false,
    this.onResizeStart,
  });
  final String metaWindowId;
  final ResizeEdge resizeEdge;
  final bool inside;
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
    // Outside handles rely on the deferred handler to be hit-tested beyond the
    // window box. Inside handles are ordinary descendants; keeping them in the
    // normal path is what makes their resize cursor visible.
    return inside ? handle : DeferPointer(child: handle);
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
