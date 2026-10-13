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
