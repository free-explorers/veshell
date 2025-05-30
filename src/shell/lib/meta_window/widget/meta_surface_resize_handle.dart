import 'package:collection/collection.dart';
import 'package:defer_pointer/defer_pointer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shell/meta_window/provider/meta_window_resizing_state.dart';
import 'package:shell/platform/model/event/interactive_resize/interactive_resize.serializable.dart';

class WithResizeHandles extends StatelessWidget {
  const WithResizeHandles({
    required this.metaWindowId,
    required this.child,
    super.key,
    this.borderWidth = 10,
    this.cornerWidth = 18,
  });
  final String metaWindowId;
  final Widget child;
  final double borderWidth;
  final double cornerWidth;

  @override
  Widget build(BuildContext context) {
    return DeferredPointerHandler(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ..._buildResizeHandles(),
          child,
        ],
      ),
    );
  }

  List<Widget> _buildResizeHandles() {
    return ResizeEdge.values.whereNot((e) => e == ResizeEdge.none).map((e) {
      return switch (e) {
        ResizeEdge.topLeft => Positioned(
            top: -borderWidth,
            left: -borderWidth,
            child: SizedBox(
              width: cornerWidth,
              height: cornerWidth,
              child: ResizeHandle(
                metaWindowId: metaWindowId,
                resizeEdge: e,
              ),
            ),
          ),
        ResizeEdge.top => Positioned(
            top: -borderWidth,
            left: cornerWidth - borderWidth,
            right: cornerWidth - borderWidth,
            child: SizedBox(
              height: borderWidth,
              child: ResizeHandle(
                metaWindowId: metaWindowId,
                resizeEdge: e,
              ),
            ),
          ),
        ResizeEdge.topRight => Positioned(
            top: -borderWidth,
            right: -borderWidth,
            child: SizedBox(
              width: cornerWidth,
              height: cornerWidth,
              child: ResizeHandle(
                metaWindowId: metaWindowId,
                resizeEdge: e,
              ),
            ),
          ),
        ResizeEdge.right => Positioned(
            top: cornerWidth - borderWidth,
            right: -borderWidth,
            bottom: cornerWidth - borderWidth,
            child: SizedBox(
              width: borderWidth,
              child: ResizeHandle(
                metaWindowId: metaWindowId,
                resizeEdge: e,
              ),
            ),
          ),
        ResizeEdge.bottomRight => Positioned(
            bottom: -borderWidth,
            right: -borderWidth,
            child: SizedBox(
              width: cornerWidth,
              height: cornerWidth,
              child: ResizeHandle(
                metaWindowId: metaWindowId,
                resizeEdge: e,
              ),
            ),
          ),
        ResizeEdge.bottom => Positioned(
            bottom: -borderWidth,
            left: cornerWidth - borderWidth,
            right: cornerWidth - borderWidth,
            child: SizedBox(
              height: borderWidth,
              child: ResizeHandle(
                metaWindowId: metaWindowId,
                resizeEdge: e,
              ),
            ),
          ),
        ResizeEdge.bottomLeft => Positioned(
            bottom: -borderWidth,
            left: -borderWidth,
            child: SizedBox(
              width: cornerWidth,
              height: cornerWidth,
              child: ResizeHandle(
                metaWindowId: metaWindowId,
                resizeEdge: e,
              ),
            ),
          ),
        ResizeEdge.left => Positioned(
            top: cornerWidth - borderWidth,
            left: -borderWidth,
            bottom: cornerWidth - borderWidth,
            child: SizedBox(
              width: borderWidth,
              child: ResizeHandle(
                metaWindowId: metaWindowId,
                resizeEdge: e,
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
  });
  final String metaWindowId;
  final ResizeEdge resizeEdge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DeferPointer(
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.translucent,
        cursor: _getMouseCursor(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) {
            ref
                .read(metaWindowResizingStateProvider(metaWindowId).notifier)
                .startResizing(resizeEdge);
          },
        ),
      ),
    );
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
