import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Scales the color saturation and the brightness of [child]: `1` leaves it
/// untouched, a [saturation] of `0` turns it to grayscale and a [brightness]
/// of `0` turns it black.
///
/// Unlike an always-present `ColorFiltered`, no offscreen layer is pushed while
/// both are `1`, so keeping this widget in the tree costs nothing for
/// the tiles that are not filtered, and toggling the filter never changes the
/// widget tree (which would remount the child).
class SaturationFilter extends SingleChildRenderObjectWidget {
  const SaturationFilter({
    required this.saturation,
    this.brightness = 1,
    super.child,
    super.key,
  });

  final double saturation;
  final double brightness;

  @override
  RenderSaturationFilter createRenderObject(BuildContext context) =>
      RenderSaturationFilter(saturation, brightness);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSaturationFilter renderObject,
  ) {
    renderObject
      ..saturation = saturation
      ..brightness = brightness;
  }
}

class RenderSaturationFilter extends RenderProxyBox {
  RenderSaturationFilter(double saturation, double brightness)
    : _saturation = saturation,
      _brightness = brightness;

  double _saturation;
  double get saturation => _saturation;
  set saturation(double value) {
    if (value == _saturation) {
      return;
    }
    _update(() => _saturation = value);
  }

  double _brightness;
  double get brightness => _brightness;
  set brightness(double value) {
    if (value == _brightness) {
      return;
    }
    _update(() => _brightness = value);
  }

  void _update(VoidCallback change) {
    final wasFiltering = _isFiltering;
    change();
    if (wasFiltering != _isFiltering) {
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  bool get _isFiltering => _saturation < 1 || _brightness < 1;

  @override
  bool get alwaysNeedsCompositing => child != null && _isFiltering;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || !_isFiltering) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushColorFilter(
      offset,
      ColorFilter.matrix(
        saturationMatrix(_saturation, brightness: _brightness),
      ),
      super.paint,
      oldLayer: layer as ColorFilterLayer?,
    );
  }
}

/// A 5x4 color matrix scaling saturation around Rec. 709 luminance, then
/// scaling the color channels by [brightness].
List<double> saturationMatrix(double saturation, {double brightness = 1}) {
  final s = saturation.clamp(0.0, 1.0);
  final k = brightness.clamp(0.0, 1.0);
  final inv = 1 - s;
  const r = 0.2126;
  const g = 0.7152;
  const b = 0.0722;
  return <double>[
    (r * inv + s) * k, g * inv * k, b * inv * k, 0, 0, //
    r * inv * k, (g * inv + s) * k, b * inv * k, 0, 0, //
    r * inv * k, g * inv * k, (b * inv + s) * k, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}
