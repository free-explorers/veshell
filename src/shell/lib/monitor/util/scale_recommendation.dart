import 'package:material_ui/material_ui.dart';

/// Scale suggestions for a monitor, shown in its fractional-scale setting.
///
/// Good scales are quarters (1, 1.25, 1.5, 1.75, 2, …): their fraction lines
/// up with the 4 and 8 pixel grids that apps and icons are designed on, so
/// spacing and 24-pixel icons land on whole pixels (1.2 puts a 24-pixel icon
/// on 28.8 pixels). Best of all is a quarter that divides the resolution
/// exactly: the screen then has a whole logical size and nothing is rounded.

/// The smallest and largest suggested scales, and the step between them.
const minSuggestedScale = 1.0;
const maxSuggestedScale = 3.0;
const suggestedScaleStep = 0.25;

/// Comfortable densities, in pixels per inch at scale 1: built-in panels are
/// looked at closer than external monitors, so they take a denser target.
const _builtInTargetDpi = 135.0;
const _externalTargetDpi = 110.0;

/// The quarter scales from [minSuggestedScale] to [maxSuggestedScale].
List<double> suggestedScales() => [
  for (
    var scale = minSuggestedScale;
    scale <= maxSuggestedScale + 1e-9;
    scale += suggestedScaleStep
  )
    scale,
];

/// Whether [scale] divides [resolution] exactly: a whole logical size.
bool isExactScale(Size resolution, double scale) {
  bool divides(double pixels) {
    final logical = pixels / scale;
    return (logical - logical.roundToDouble()).abs() < 1e-6;
  }

  return divides(resolution.width) && divides(resolution.height);
}

/// The suggested scales that divide [resolution] exactly.
List<double> exactScales(Size resolution) => [
  for (final scale in suggestedScales())
    if (isExactScale(resolution, scale)) scale,
];

/// Whether a connector name is a laptop's built-in panel.
bool isBuiltInConnector(String connector) {
  final name = connector.toUpperCase();
  return name.startsWith('EDP') ||
      name.startsWith('LVDS') ||
      name.startsWith('DSI');
}

/// The recommended scale for a panel of [resolution] pixels and
/// [physicalSize] millimetres, or `null` when its size is unknown (a
/// projector, many TVs).
///
/// The scale brings the panel's density closest to a comfortable target.
/// An exact scale (see [isExactScale]) within one step of that is preferred.
double? recommendedScale(
  Size resolution,
  Size physicalSize, {
  required bool builtIn,
}) {
  if (resolution.isEmpty || physicalSize.width <= 0) return null;
  if (_isAspectRatio(physicalSize)) return null;
  final dpi = resolution.width / (physicalSize.width / 25.4);
  // A reported size that cannot be a real panel.
  if (!dpi.isFinite || dpi < 40 || dpi > 700) return null;
  final target = (dpi / (builtIn ? _builtInTargetDpi : _externalTargetDpi))
      .clamp(minSuggestedScale, maxSuggestedScale);
  double closest(Iterable<double> scales) =>
      scales.reduce((a, b) => (a - target).abs() <= (b - target).abs() ? a : b);
  final nearest = closest(suggestedScales());
  final exact = exactScales(resolution);
  if (exact.isNotEmpty) {
    final nearestExact = closest(exact);
    if ((nearestExact - target).abs() <= suggestedScaleStep + 1e-9) {
      return nearestExact;
    }
  }
  return nearest;
}

/// Whether [size] is an aspect ratio rather than a size: some EDIDs (often
/// projectors and TVs) put 16 by 9 or 16 by 10 there, in centimetres, which
/// arrives as 160 x 90 mm and would pass for a small panel.
bool _isAspectRatio(Size size) {
  const ratios = [(16, 9), (16, 10), (4, 3), (5, 4), (21, 9)];
  for (final (w, h) in ratios) {
    for (final unit in const [1, 10]) {
      if (size.width == w * unit && size.height == h * unit) return true;
    }
  }
  return false;
}

/// [scale] for display: `1`, `1.25`, `1.5`.
String formatScale(double scale, String decimalSeparator) {
  final text = scale
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return text.replaceAll('.', decimalSeparator);
}
