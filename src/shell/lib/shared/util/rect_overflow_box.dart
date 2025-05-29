import 'package:flutter/material.dart';

// Crops the child to a rectangle inside it.
// The size of this widget will be the size of the rectangle.
// The child can still visually overflow even though hit-testing doesn't work outside the rectangle.
class CropOverflowBox extends StatelessWidget {
  const CropOverflowBox({
    required this.rect,
    required this.child,
    super.key,
    this.resetTopLeft = false,
  });
  final Widget child;
  final Rect rect;
  final bool resetTopLeft;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: resetTopLeft ? Offset.zero : rect.topLeft,
      child: SizedOverflowBox(
        alignment: Alignment.topLeft,
        size: rect.size + rect.topLeft,
        child: Transform.translate(
          offset: -rect.topLeft,
          child: child,
        ),
      ),
    );
  }
}

class TransformBox extends StatelessWidget {
  const TransformBox({
    required this.from,
    required this.to,
    required this.child,
    super.key,
  });
  final Rect from;
  final Rect to;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      alignment: Alignment.topLeft,
      scaleX: to.width / from.width,
      scaleY: to.height / from.height,
      child: child,
    );
  }
}
