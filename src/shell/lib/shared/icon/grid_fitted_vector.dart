import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/icon/grid_fit.dart';
import 'package:shell/shared/widget/physical_pixel_snap.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

/// Draws [instructions] grid-fitted into a square of [size] logical pixels:
/// at the exact size, with straight edges on whole physical pixels.
///
/// The square starts on a whole physical pixel (`PhysicalPixelSnap`), which
/// the fit assumes. A non-null [color] replaces the icon's own colours, as an
/// `Icon` does for a symbol.
class GridFittedVector extends StatelessWidget {
  const GridFittedVector({
    required this.instructions,
    required this.size,
    this.color,
    super.key,
  });

  final vg.VectorInstructions instructions;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return PhysicalPixelSnap(
      child: CustomPaint(
        size: Size.square(size),
        painter: _GridFitPainter(
          instructions: instructions,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          color: color,
        ),
      ),
    );
  }
}

class _GridFitPainter extends CustomPainter {
  _GridFitPainter({
    required this.instructions,
    required this.devicePixelRatio,
    required this.color,
  });

  final vg.VectorInstructions instructions;
  final double devicePixelRatio;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final pixels = size.shortestSide * devicePixelRatio;
    if (pixels <= 0) return;
    final picture = _GridFitCache.picture(instructions, pixels, color);
    canvas
      ..save()
      // Draw in physical pixels, where the fit happened.
      ..scale(1 / devicePixelRatio)
      ..drawPicture(picture)
      ..restore();
  }

  @override
  bool shouldRepaint(_GridFitPainter oldDelegate) =>
      !identical(oldDelegate.instructions, instructions) ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      oldDelegate.color != color;
}

/// Fitted pictures, by icon, pixel size and colour.
///
/// Fitting is cheap but not free, and every frame of a panel repaints the same
/// few icons. Least-recently-used, bounded: pictures are only dropped, never
/// disposed, so a picture still held by a layer stays valid.
abstract final class _GridFitCache {
  static const _capacity = 512;
  static final _pictures = <_Key, ui.Picture>{};

  static ui.Picture picture(
    vg.VectorInstructions instructions,
    double pixels,
    Color? color,
  ) {
    final key = _Key(instructions, (pixels * 1000).round(), color?.toARGB32());
    final cached = _pictures.remove(key);
    if (cached != null) {
      _pictures[key] = cached;
      return cached;
    }
    final picture = GridFit(instructions, pixels).record(color: color);
    _pictures[key] = picture;
    if (_pictures.length > _capacity) {
      _pictures.remove(_pictures.keys.first);
    }
    return picture;
  }
}

@immutable
class _Key {
  const _Key(this.instructions, this.millipixels, this.color);

  final vg.VectorInstructions instructions;
  final int millipixels;
  final int? color;

  @override
  bool operator ==(Object other) =>
      other is _Key &&
      identical(other.instructions, instructions) &&
      other.millipixels == millipixels &&
      other.color == color;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(instructions), millipixels, color);
}
