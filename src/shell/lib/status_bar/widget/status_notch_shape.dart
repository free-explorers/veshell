import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// The outline of the status notch: hung from the top edge of its box, it
/// fills its height and wraps each of its sides in a double curve.
///
/// On each side, a concave arc of [capRadius] centered on the top corner's
/// vertical line at [capCenterY] flares into the top edge; next to the
/// visible tile picker it is concentric with the picker's rounded end, so the
/// notch keeps the same gap all around it. A convex fillet of [filletRadius]
/// then turns it into the flat bottom edge.
class StatusNotchShape {
  const StatusNotchShape({
    required this.capRadius,
    required this.capCenterY,
    required this.filletRadius,
  });

  final double capRadius;
  final double capCenterY;
  final double filletRadius;

  /// How far, from a side of the box, the fillet meets the bottom edge.
  double inset(double height) {
    final dy = height - filletRadius - capCenterY;
    return sqrt(max(0, pow(capRadius + filletRadius, 2) - dy * dy));
  }

  Path pathFor(Size size) {
    final width = size.width;
    final height = size.height;
    final dx = inset(height);
    final dy = height - filletRadius - capCenterY;

    final rightCap = Rect.fromCircle(
      center: Offset(width, capCenterY),
      radius: capRadius,
    );
    final rightFillet = Rect.fromCircle(
      center: Offset(width - dx, height - filletRadius),
      radius: filletRadius,
    );
    final leftFillet = Rect.fromCircle(
      center: Offset(dx, height - filletRadius),
      radius: filletRadius,
    );
    final leftCap = Rect.fromCircle(
      center: Offset(0, capCenterY),
      radius: capRadius,
    );

    // Angle, around a cap, of the point where it meets its fillet (on the
    // right side; the left side mirrors it).
    final meet = atan2(dy, -dx);
    // y grows downwards, so a positive sweep turns clockwise on screen.
    return Path()
      ..moveTo(0, 0)
      ..lineTo(width, 0)
      // Around the picker's end, from the top edge to the right fillet.
      ..arcTo(rightCap, -pi / 2, meet - 2 * pi + pi / 2, false)
      ..arcTo(rightFillet, meet - pi, pi / 2 - (meet - pi), false)
      ..lineTo(dx, height)
      ..arcTo(leftFillet, pi / 2, (2 * pi - meet) - pi / 2, false)
      // Back up to the top edge.
      ..arcTo(leftCap, pi - meet, -pi / 2 - (pi - meet), false)
      ..close();
  }
}

class StatusNotchClipper extends CustomClipper<Path> {
  const StatusNotchClipper(this.shape);

  final StatusNotchShape shape;

  @override
  Path getClip(Size size) => shape.pathFor(size);

  @override
  bool shouldReclip(StatusNotchClipper oldClipper) =>
      shape.capRadius != oldClipper.shape.capRadius ||
      shape.capCenterY != oldClipper.shape.capCenterY ||
      shape.filletRadius != oldClipper.shape.filletRadius;
}
