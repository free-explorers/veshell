import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/icon/grid_fit.dart';
import 'package:shell/shared/widget/physical_pixel_snap.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

/// Draws [instructions] grid-fitted into a square of [size] logical pixels:
/// at the exact size, with straight edges on whole physical pixels.
///
/// The square is always [size], centred in whatever box the parent gives:
/// a parent's tight constraints (a 48-pixel `InputDecoration` icon slot, a
/// fixed-size button) never stretch the icon. The square starts on a whole
/// physical pixel (`PhysicalPixelSnap`), which the fit assumes. A non-null
/// [color] replaces the icon's own colours, as an `Icon` does for a symbol.
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
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: PhysicalPixelSnap(
          child: CustomPaint(
            size: Size.square(size),
            painter: _GridFitPainter(
              instructions: instructions,
              size: size,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridFitPainter extends CustomPainter {
  _GridFitPainter({
    required this.instructions,
    required this.size,
    required this.devicePixelRatio,
    required this.color,
  });

  final vg.VectorInstructions instructions;

  /// The icon's size, in logical pixels: what is drawn, whatever box the
  /// painter ends up with.
  final double size;
  final double devicePixelRatio;
  final Color? color;

  @override
  void paint(Canvas canvas, Size box) {
    final pixels = size * devicePixelRatio;
    if (pixels <= 0) return;
    final image = _GridFitCache.image(instructions, pixels, color);
    canvas
      ..save()
      // Like an SVG viewport, keep the icon to its square: paths past the
      // view box would otherwise paint over neighbouring widgets.
      ..clipRect(Offset.zero & Size.square(size))
      // Draw in physical pixels, where the fit happened: on the pixel grid,
      // the image lands one to one. Off it (a transform, an animation),
      // bilinear sampling keeps the icon smooth instead of snapping it a
      // whole pixel.
      ..scale(1 / devicePixelRatio)
      ..drawImage(
        image,
        Offset.zero,
        Paint()..filterQuality = FilterQuality.low,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GridFitPainter oldDelegate) =>
      !identical(oldDelegate.instructions, instructions) ||
      oldDelegate.size != size ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      oldDelegate.color != color;
}

/// Fitted icons rasterized, by icon, pixel size and colour.
///
/// A picture rasterized with `toImageSync` renders in a multisampled
/// offscreen pass, once; every frame after that draws a plain image, which is
/// far cheaper than replaying the paths (Impeller has no raster cache). It
/// also keeps icons antialiased when the compositor's own multisampling is
/// off (`theme.antialiasing`): Impeller antialiases paths only by sampling.
///
/// Least-recently-used, bounded by bytes: an icon animated through many sizes
/// leaves one image per size. Evicted images are disposed; a frame that
/// already drew one keeps its own reference to the pixels.
abstract final class _GridFitCache {
  static const _budgetBytes = 32 << 20;
  static final _images = <_Key, ui.Image>{};
  static int _bytes = 0;

  static ui.Image image(
    vg.VectorInstructions instructions,
    double pixels,
    Color? color,
  ) {
    final key = _Key(instructions, (pixels * 1000).round(), color?.toARGB32());
    final cached = _images.remove(key);
    if (cached != null) {
      _images[key] = cached;
      return cached;
    }
    final extent = pixels.ceil();
    final picture = GridFit(instructions, pixels).record(color: color);
    final image = picture.toImageSync(extent, extent);
    picture.dispose();
    _images[key] = image;
    _bytes += _sizeOf(image);
    while (_bytes > _budgetBytes && _images.length > 1) {
      final oldest = _images.keys.first;
      final evicted = _images.remove(oldest)!;
      _bytes -= _sizeOf(evicted);
      evicted.dispose();
    }
    return image;
  }

  static int _sizeOf(ui.Image image) => image.width * image.height * 4;
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
