import 'package:flutter/rendering.dart';

/// Marks a multi-box sliver that paints every child it has built, even one
/// whose slot is out of view (one shown sliding over a visible slot), so
/// [paintPlacement] does not report those children unpainted.
abstract interface class ProbePaintsEveryChild {}

/// Where [box] is on its view: its `rect`, the part of it ancestor clips
/// leave in view (`visibleRect`, `null` when clipped away entirely), the
/// product of its ancestors' opacities, and whether its ancestors paint it
/// at all (`painted`): a box laid out but skipped by its ancestors' paint
/// (offstage, a sliver child whose slot is out of view, a sliver the
/// viewport does not show) is not on screen whatever its rect.
({Rect rect, Rect? visibleRect, double opacity, bool painted}) paintPlacement(
  RenderBox box,
) {
  final rect = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  Rect? visible = rect;
  var opacity = 1.0;
  var painted = true;
  RenderObject child = box;
  var parent = box.parent;
  while (parent != null) {
    painted &= _paints(parent, child);
    if (parent is RenderOpacity) {
      opacity *= parent.opacity;
    } else if (parent is RenderAnimatedOpacityMixin) {
      opacity *= parent.opacity.value;
    } else if (parent is RenderOffstage && parent.offstage) {
      opacity = 0;
    }
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null && visible != null) {
      final globalClip = MatrixUtils.transformRect(
        parent.getTransformTo(null),
        clip,
      );
      visible = visible.intersect(globalClip);
      if (visible.isEmpty) {
        visible = null;
      }
    }
    child = parent;
    parent = parent.parent;
  }
  if (child is RenderView && visible != null) {
    visible = visible.intersect(Offset.zero & child.size);
    if (visible.isEmpty) {
      visible = null;
    }
  }
  return (rect: rect, visibleRect: visible, opacity: opacity, painted: painted);
}

/// Whether [parent]'s paint paints [child]: its own `paintsChild`, plus what
/// that misses: a viewport only paints the slivers it shows, and a multi-box
/// sliver only the children whose slot overlaps its paint extent.
bool _paints(RenderObject parent, RenderObject child) {
  if (!parent.paintsChild(child)) {
    return false;
  }
  if (parent is RenderViewportBase && child is RenderSliver) {
    return child.geometry?.visible ?? false;
  }
  if (parent is RenderSliverMultiBoxAdaptor &&
      parent is! ProbePaintsEveryChild &&
      child is RenderBox &&
      child.hasSize) {
    // As `RenderSliverMultiBoxAdaptor.paint` decides.
    final position = parent.childMainAxisPosition(child);
    final extent = switch (parent.constraints.axis) {
      Axis.horizontal => child.size.width,
      Axis.vertical => child.size.height,
    };
    return position < parent.constraints.remainingPaintExtent &&
        position + extent > 0;
  }
  return true;
}
