import 'package:material_ui/material_ui.dart';

/// Snaps a logical-pixel coordinate to the whole-pixel grid.
///
/// A live Wayland surface is drawn as an external Flutter `Texture` sampled
/// bilinearly (`FilterQuality.low`, the widget default). When its origin lands
/// on a fractional logical pixel the sampler softens the whole surface, so a
/// window that should map 1:1 to its client buffer comes out permanently
/// blurry. Widgets that place a surface keep its origin on whole pixels (see
/// `OverviewWidget`, which does the same for the overview content pane).
double snapToWholePixel(double value) => value.roundToDouble();

/// [snapToWholePixel] applied to an [Offset].
Offset snapOffsetToWholePixels(Offset offset) =>
    Offset(snapToWholePixel(offset.dx), snapToWholePixel(offset.dy));

/// Snaps a scroll viewport to a whole number of `count` whole-pixel pages.
///
/// Each page is `extent / count` wide; when that is fractional every page
/// after the first starts off the logical pixel grid. Returning the viewport
/// rounded down to `count` whole-pixel pages keeps every page origin integral,
/// at the cost of at most `count - 1` unused pixels at the trailing edge.
///
/// An unbounded [extent], or one smaller than a single pixel per page, is
/// returned unchanged so the caller behaves as it did without snapping.
double snapPageViewport(double extent, int count) {
  if (!extent.isFinite || count <= 0) {
    return extent;
  }
  final pageDimension = (extent / count).floorToDouble();
  return pageDimension >= 1 ? pageDimension * count : extent;
}
