import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A Material 3 slider whose track carries a label.
///
/// The label sits inside the rounded track, in the same place M3 Expressive
/// puts its optional inset icon. It is painted once, at the leading edge, and
/// each part takes the foreground colour of the track segment it covers: the
/// active track or the inactive track. The transparent gap around the handle
/// stays clear. Long labels are ellipsized to the track width.
class DeviceSlider extends StatelessWidget {
  const DeviceSlider({
    required this.value,
    required this.label,
    required this.onChanged,
    this.trackHeight = 24,
    this.trackGap = 6,
    this.handleHeight = 32,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    super.key,
  });

  final double value;
  final String label;
  final ValueChanged<double>? onChanged;
  final double trackHeight;
  final double trackGap;
  final double handleHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SliderTheme(
      data: SliderThemeData(
        padding: padding,
        trackHeight: trackHeight,
        trackGap: trackGap,
        thumbShape: _SizedHandleThumbShape(handleHeight: handleHeight),
        thumbSize: WidgetStateProperty.resolveWith((states) {
          final isThin =
              states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused);
          return Size(isThin ? 2 : 4, handleHeight);
        }),
        trackShape: _LabeledTrackShape(
          label: label,
          trackGap: trackGap,
          textStyle: theme.textTheme.labelMedium!,
          textScaler: MediaQuery.textScalerOf(context),
          activeTextColor: colors.onPrimary,
          inactiveTextColor: colors.onSecondaryContainer,
          disabledTextColor: colors.onSurface.withValues(alpha: 0.38),
        ),
      ),
      // The 2024 slider appearance is still opt-in through this deprecated
      // flag in the pinned material_ui version.
      // ignore: deprecated_member_use
      child: Slider(year2023: false, value: value, onChanged: onChanged),
    );
  }
}

class _SizedHandleThumbShape extends HandleThumbShape {
  const _SizedHandleThumbShape({required this.handleHeight});

  final double handleHeight;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(4, handleHeight);
  }
}

class _LabeledTrackShape extends GappedSliderTrackShape {
  const _LabeledTrackShape({
    required this.label,
    required this.trackGap,
    required this.textStyle,
    required this.textScaler,
    required this.activeTextColor,
    required this.inactiveTextColor,
    required this.disabledTextColor,
  });

  static const _edgePadding = 12.0;
  static const _innerRadius = 2.0;
  static const _stopIndicatorRadius = 2.0;
  static const _stopIndicatorDiameter = 4.0;

  final String label;
  final double trackGap;
  final TextStyle textStyle;
  final TextScaler textScaler;
  final Color activeTextColor;
  final Color inactiveTextColor;
  final Color disabledTextColor;

  /// The expressive handle is only 4 dp wide, so it does not need the
  /// track-height inset that [GappedSliderTrackShape] applies to round thumbs.
  /// Reporting an unrounded track lets the handle travel to the real track
  /// ends instead of stopping half the track height short of them.
  @override
  bool get isRounded => false;

  /// Inset the handle's travel range by one gap on each side. The track itself
  /// is painted back to the full width in [paint], so only the handle and the
  /// stop indicator are padded from the rounded ends.
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    Offset offset = Offset.zero,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final rect = super.getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    return Rect.fromLTRB(
      rect.left + trackGap,
      rect.top,
      rect.right - trackGap,
      rect.bottom,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final isLtr = textDirection == TextDirection.ltr;
    final shapeRect = Rect.fromLTRB(
      trackRect.left - trackGap,
      trackRect.top,
      trackRect.right + trackGap,
      trackRect.bottom,
    );
    final leadingEnd = isLtr
        ? thumbCenter.dx - trackGap
        : thumbCenter.dx + trackGap;
    final trailingStart = isLtr
        ? thumbCenter.dx + trackGap
        : thumbCenter.dx - trackGap;
    final activeRect = isLtr
        ? Rect.fromLTRB(
            shapeRect.left,
            shapeRect.top,
            leadingEnd,
            shapeRect.bottom,
          )
        : Rect.fromLTRB(
            leadingEnd,
            shapeRect.top,
            shapeRect.right,
            shapeRect.bottom,
          );
    final inactiveRect = isLtr
        ? Rect.fromLTRB(
            trailingStart,
            shapeRect.top,
            shapeRect.right,
            shapeRect.bottom,
          )
        : Rect.fromLTRB(
            shapeRect.left,
            shapeRect.top,
            trailingStart,
            shapeRect.bottom,
          );
    final activeWidth = math.max<double>(0, activeRect.width);
    final inactiveWidth = math.max<double>(0, inactiveRect.width);

    _paintTrack(
      context,
      shapeRect,
      sliderTheme,
      enableAnimation,
      textDirection,
      activeRect: activeRect,
      inactiveRect: inactiveRect,
      activeWidth: activeWidth,
      inactiveWidth: inactiveWidth,
      stopIndicatorX: isLtr ? trackRect.right : trackRect.left,
    );

    if (label.isEmpty || shapeRect.width <= _edgePadding * 2) {
      return;
    }

    final activePainter = _textPainter(
      Color.lerp(disabledTextColor, activeTextColor, enableAnimation.value)!,
      shapeRect.width - _edgePadding * 2,
      textDirection,
    );
    final inactivePainter = _textPainter(
      Color.lerp(disabledTextColor, inactiveTextColor, enableAnimation.value)!,
      shapeRect.width - _edgePadding * 2,
      textDirection,
    );
    if (activePainter.width <= 0) {
      return;
    }

    final dx = isLtr
        ? shapeRect.left + _edgePadding
        : shapeRect.right - _edgePadding - activePainter.width;
    final dy = shapeRect.center.dy - activePainter.height / 2;
    final textOffset = Offset(dx, dy);

    final trackRRect = RRect.fromRectAndRadius(
      shapeRect,
      Radius.circular(shapeRect.height / 2),
    );
    final canvas = context.canvas
      ..save()
      ..clipRRect(trackRRect);
    if (activeWidth > 0) {
      _paintInClip(canvas, activeRect, activePainter, textOffset);
    }
    if (inactiveWidth > 0) {
      _paintInClip(canvas, inactiveRect, inactivePainter, textOffset);
    }
    canvas.restore();
  }

  void _paintTrack(
    PaintingContext context,
    Rect trackRect,
    SliderThemeData sliderTheme,
    Animation<double> enableAnimation,
    TextDirection textDirection, {
    required Rect activeRect,
    required Rect inactiveRect,
    required double activeWidth,
    required double inactiveWidth,
    required double stopIndicatorX,
  }) {
    final activePaint = Paint()
      ..color = ColorTween(
        begin: sliderTheme.disabledActiveTrackColor,
        end: sliderTheme.activeTrackColor,
      ).evaluate(enableAnimation)!;
    final inactivePaint = Paint()
      ..color = ColorTween(
        begin: sliderTheme.disabledInactiveTrackColor,
        end: sliderTheme.inactiveTrackColor,
      ).evaluate(enableAnimation)!;
    final isLtr = textDirection == TextDirection.ltr;
    final radius = trackRect.height / 2;
    final trackRRect = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(radius),
    );

    final canvas = context.canvas
      ..save()
      ..clipRRect(trackRRect);
    if (activeWidth > 0) {
      _drawSegment(
        canvas,
        activeRect,
        activePaint,
        isLtr ? radius : _innerRadius,
        isLtr ? _innerRadius : radius,
      );
    }
    if (inactiveWidth > 0) {
      _drawSegment(
        canvas,
        inactiveRect,
        inactivePaint,
        isLtr ? _innerRadius : radius,
        isLtr ? radius : _innerRadius,
      );
    }
    canvas.restore();

    if (inactiveWidth > _stopIndicatorDiameter) {
      final stopIndicatorOffset = Offset(stopIndicatorX, trackRect.center.dy);
      final stopIndicatorColor = Color.lerp(
        disabledTextColor,
        inactiveTextColor,
        enableAnimation.value,
      )!;
      canvas.drawCircle(
        stopIndicatorOffset,
        _stopIndicatorRadius,
        Paint()..color = stopIndicatorColor,
      );
    }
  }

  void _drawSegment(
    Canvas canvas,
    Rect rect,
    Paint paint,
    double startCorner,
    double endCorner,
  ) {
    if (rect.width <= 0) {
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.circular(startCorner),
        bottomLeft: Radius.circular(startCorner),
        topRight: Radius.circular(endCorner),
        bottomRight: Radius.circular(endCorner),
      ),
      paint,
    );
  }

  void _paintInClip(
    Canvas canvas,
    Rect clip,
    TextPainter painter,
    Offset offset,
  ) {
    canvas
      ..save()
      ..clipRect(clip);
    painter.paint(canvas, offset);
    canvas.restore();
  }

  TextPainter _textPainter(
    Color color,
    double maxWidth,
    TextDirection textDirection,
  ) {
    return TextPainter(
      text: TextSpan(
        text: label,
        style: textStyle.copyWith(color: color),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
  }
}
