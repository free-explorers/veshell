import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

/// Grid fitting ("hinting") for vector icons.
///
/// An icon drawn at a fractional pixel size (24 logical pixels at scale 1.2
/// is 28.8 pixels) puts its straight edges between pixels, so every bar,
/// frame and border is anti-aliased over two pixels and the icon looks soft.
/// Drawing a larger design scaled down does not help: a vector drawn at the
/// target size already is the ideal downscale.
///
/// Grid fitting keeps the exact size and moves geometry instead, the way
/// TrueType hinting does:
/// - straight horizontal and vertical edges ("anchors") are moved to whole
///   pixels, at most half a pixel each;
/// - pairs of close edges (stems) keep a consistent width, rounded to the
///   nearest pixel and never collapsed below one;
/// - every other point, curve control points included, is interpolated
///   between the anchors on each axis, so shapes stay continuous;
/// - stroke widths round to whole pixels, and a stroke of odd width is
///   centred on a pixel centre.
///
/// Curves and diagonals stay anti-aliased: that is what they look like at any
/// size. Gradients follow the unfitted geometry; they have no edges.

/// Edges closer than this, in pixels, form a stem whose width is preserved.
const _stemMax = 3.0;

/// A straight segment shorter than this, in pixels, is not an edge worth
/// snapping (the corner of a curve, a tiny notch).
const _edgeMinLength = 0.5;

const _epsilon = 1e-3;

/// One axis of the fit: a monotonic, piecewise-linear map through the snapped
/// anchors.
class AxisFit {
  /// Builds the map from anchors: original position -> preferred target.
  ///
  /// Targets are made consistent here: close anchors keep their distance
  /// rounded to whole pixels (a 2.36 pixel bar stays 2 pixels wide on both
  /// sides of a `+`), and the map never folds over itself.
  factory AxisFit(Map<double, double> anchors) {
    final from = anchors.keys.toList()..sort();
    final to = <double>[];
    for (var i = 0; i < from.length; i++) {
      var target = anchors[from[i]]!;
      if (i > 0) {
        final gap = from[i] - from[i - 1];
        final previous = to[i - 1];
        if (gap <= _stemMax) {
          // A stem: keep its width, rounded, at least one pixel when the
          // original was visible at all.
          final width = gap < 0.5 ? gap : math.max(1, gap.round()).toDouble();
          final stemTarget = previous + width;
          // Only take the stem width when it stays close to the edge's own
          // position; otherwise snapping errors would accumulate.
          if ((stemTarget - from[i]).abs() <= 1) target = stemTarget;
        }
        // Monotonic: an anchor never crosses the previous one, and a visible
        // gap never collapses.
        final minimum = previous + (gap >= 0.5 ? 1 : 0);
        if (target < minimum) target = minimum;
      }
      to.add(target);
    }
    return AxisFit._(Float64List.fromList(from), Float64List.fromList(to));
  }

  AxisFit._(this._from, this._to);

  /// The identity map.
  static final identity = AxisFit._(Float64List(0), Float64List(0));

  final Float64List _from;
  final Float64List _to;

  /// Number of anchors.
  int get length => _from.length;

  double call(double v) {
    if (_from.isEmpty) return v;
    if (v <= _from.first) return v + (_to.first - _from.first);
    if (v >= _from.last) return v + (_to.last - _from.last);
    var low = 0;
    var high = _from.length - 1;
    while (high - low > 1) {
      final mid = (low + high) >> 1;
      if (_from[mid] <= v) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final a = _from[low];
    final b = _from[high];
    final t = (v - a) / (b - a);
    return _to[low] + (_to[high] - _to[low]) * t;
  }
}

/// Whether [instructions] only use what [GridFit] can draw: paths, layers and
/// clips. Masks, text, embedded images, patterns and vertices are drawn by the
/// regular renderer instead.
bool isGridFittable(vg.VectorInstructions instructions) {
  if (instructions.width <= 0 || instructions.height <= 0) return false;
  for (final command in instructions.commands) {
    switch (command.type) {
      case vg.DrawCommandType.path:
      case vg.DrawCommandType.saveLayer:
      case vg.DrawCommandType.restore:
      case vg.DrawCommandType.clip:
        break;
      case vg.DrawCommandType.vertices:
      case vg.DrawCommandType.mask:
      case vg.DrawCommandType.text:
      case vg.DrawCommandType.image:
      case vg.DrawCommandType.pattern:
      case vg.DrawCommandType.textPosition:
        return false;
    }
  }
  return true;
}

/// [instructions] fitted into a square of [pixels] physical pixels.
///
/// The icon is scaled to fit and centred, like `BoxFit.contain`; the fit then
/// assumes the square's top-left corner lies on a whole pixel (see
/// `PhysicalPixelSnap`).
class GridFit {
  GridFit(this.instructions, this.pixels, {this.fit = true}) {
    scale = pixels / math.max(instructions.width, instructions.height);
    offsetX = (pixels - instructions.width * scale) / 2;
    offsetY = (pixels - instructions.height * scale) / 2;
    if (fit) {
      _collectAnchors();
    } else {
      x = AxisFit.identity;
      y = AxisFit.identity;
    }
  }

  final vg.VectorInstructions instructions;

  /// Side of the target square, in physical pixels; usually fractional.
  final double pixels;

  /// Whether to fit at all; `false` draws the plain, scaled icon.
  final bool fit;

  late final double scale;
  late final double offsetX;
  late final double offsetY;
  late final AxisFit x;
  late final AxisFit y;

  double _px(double v) => offsetX + v * scale;
  double _py(double v) => offsetY + v * scale;

  /// A stroke width fitted to whole pixels.
  double strokeWidth(double? width) {
    final scaled = (width ?? 1) * scale;
    return fit ? math.max(1, scaled.round()).toDouble() : scaled;
  }

  void _collectAnchors() {
    final xs = <double, double>{};
    final ys = <double, double>{};
    for (final command in instructions.commands) {
      if (command.type != vg.DrawCommandType.path &&
          command.type != vg.DrawCommandType.clip) {
        continue;
      }
      final stroke = command.paintId == null
          ? null
          : instructions.paints[command.paintId!].stroke;
      // A fill edge snaps to a pixel boundary. A stroke's centre line snaps
      // to a pixel centre when its fitted width is odd, so both of its edges
      // land on boundaries.
      final half = stroke != null && strokeWidth(stroke.width).toInt().isOdd;
      double target(double v) =>
          half ? (v - 0.5).roundToDouble() + 0.5 : v.roundToDouble();

      void edge(Map<double, double> map, double v) =>
          map.putIfAbsent(v, () => target(v));

      final commands = instructions.paths[command.objectId!].commands;
      double? startX;
      double? startY;
      double? lastX;
      double? lastY;
      for (final c in commands) {
        double? nx;
        double? ny;
        if (c is vg.MoveToCommand) {
          startX = lastX = _px(c.x);
          startY = lastY = _py(c.y);
          continue;
        } else if (c is vg.LineToCommand) {
          nx = _px(c.x);
          ny = _py(c.y);
        } else if (c is vg.CubicToCommand) {
          nx = _px(c.x3);
          ny = _py(c.y3);
          // An axis-aligned tangent at a curve's end is an extremum: the
          // visible edge of a rounded shape.
          final cx = _px(c.x2);
          final cy = _py(c.y2);
          if ((cy - ny).abs() < _epsilon && (cx - nx).abs() > _epsilon) {
            edge(ys, ny);
          }
          if ((cx - nx).abs() < _epsilon && (cy - ny).abs() > _epsilon) {
            edge(xs, nx);
          }
          lastX = nx;
          lastY = ny;
          continue;
        } else if (c is vg.CloseCommand) {
          nx = startX;
          ny = startY;
        }
        if (nx == null || ny == null || lastX == null || lastY == null) {
          continue;
        }
        if ((ny - lastY).abs() < _epsilon &&
            (nx - lastX).abs() >= _edgeMinLength) {
          edge(ys, ny);
        }
        if ((nx - lastX).abs() < _epsilon &&
            (ny - lastY).abs() >= _edgeMinLength) {
          edge(xs, nx);
        }
        lastX = nx;
        lastY = ny;
      }
    }
    x = AxisFit(xs);
    y = AxisFit(ys);
  }

  /// A point of the icon, in physical pixels of the target square.
  ui.Offset point(double px, double py) => ui.Offset(x(_px(px)), y(_py(py)));

  /// [path] fitted into the target square.
  ui.Path path(vg.Path path) {
    final out = ui.Path()
      ..fillType = path.fillType == vg.PathFillType.evenOdd
          ? ui.PathFillType.evenOdd
          : ui.PathFillType.nonZero;
    for (final c in path.commands) {
      if (c is vg.MoveToCommand) {
        final p = point(c.x, c.y);
        out.moveTo(p.dx, p.dy);
      } else if (c is vg.LineToCommand) {
        final p = point(c.x, c.y);
        out.lineTo(p.dx, p.dy);
      } else if (c is vg.CubicToCommand) {
        final a = point(c.x1, c.y1);
        final b = point(c.x2, c.y2);
        final e = point(c.x3, c.y3);
        out.cubicTo(a.dx, a.dy, b.dx, b.dy, e.dx, e.dy);
      } else if (c is vg.CloseCommand) {
        out.close();
      }
    }
    return out;
  }

  /// The icon-space -> target-square matrix, for gradients, which follow the
  /// unfitted geometry.
  Float64List _shaderMatrix(vg.AffineMatrix? transform) {
    final matrix = Float64List(16)
      ..[0] = scale
      ..[5] = scale
      ..[10] = 1
      ..[12] = offsetX
      ..[13] = offsetY
      ..[15] = 1;
    if (transform == null) return matrix;
    final t = transform.toMatrix4();
    // matrix * t, both column-major 4x4.
    final out = Float64List(16);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += matrix[k * 4 + row] * t[col * 4 + k];
        }
        out[col * 4 + row] = sum;
      }
    }
    return out;
  }

  ui.Shader? _shader(vg.Gradient? gradient) {
    if (gradient == null) return null;
    final colors =
        gradient.colors?.map((c) => ui.Color(c.value)).toList() ??
        const <ui.Color>[];
    if (colors.length < 2) return null;
    final stops = gradient.offsets;
    final tileMode = switch (gradient.tileMode) {
      vg.TileMode.repeated => ui.TileMode.repeated,
      vg.TileMode.mirror => ui.TileMode.mirror,
      vg.TileMode.decal => ui.TileMode.decal,
      vg.TileMode.clamp || null => ui.TileMode.clamp,
    };
    final matrix = _shaderMatrix(gradient.transform);
    if (gradient is vg.LinearGradient) {
      return ui.Gradient.linear(
        ui.Offset(gradient.from.x, gradient.from.y),
        ui.Offset(gradient.to.x, gradient.to.y),
        colors,
        stops,
        tileMode,
        matrix,
      );
    }
    if (gradient is vg.RadialGradient) {
      final focal = gradient.focalPoint;
      return ui.Gradient.radial(
        ui.Offset(gradient.center.x, gradient.center.y),
        gradient.radius,
        colors,
        stops,
        tileMode,
        matrix,
        focal == null ? null : ui.Offset(focal.x, focal.y),
      );
    }
    return null;
  }

  ui.Paint _paint(vg.Paint paint, {required bool stroke, ui.Color? color}) {
    final out = ui.Paint()
      ..isAntiAlias = true
      ..blendMode = ui.BlendMode.values.firstWhere(
        (mode) => mode.name == paint.blendMode.name,
        orElse: () => ui.BlendMode.srcOver,
      );
    if (stroke) {
      final s = paint.stroke!;
      out
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = strokeWidth(s.width)
        ..strokeCap = switch (s.cap) {
          vg.StrokeCap.round => ui.StrokeCap.round,
          vg.StrokeCap.square => ui.StrokeCap.square,
          vg.StrokeCap.butt || null => ui.StrokeCap.butt,
        }
        ..strokeJoin = switch (s.join) {
          vg.StrokeJoin.round => ui.StrokeJoin.round,
          vg.StrokeJoin.bevel => ui.StrokeJoin.bevel,
          vg.StrokeJoin.miter || null => ui.StrokeJoin.miter,
        }
        ..strokeMiterLimit = s.miterLimit ?? 4;
      _colorize(out, s.color, s.shader, color);
    } else {
      final f = paint.fill!;
      _colorize(out, f.color, f.shader, color);
    }
    return out;
  }

  void _colorize(
    ui.Paint out,
    vg.Color source,
    vg.Gradient? gradient,
    ui.Color? color,
  ) {
    if (color != null) {
      // A symbol takes its colour from the theme; only the source alpha is
      // kept, as a modulation.
      out.color = color.withValues(
        alpha: color.a * ((source.value >> 24) & 0xFF) / 255,
      );
      return;
    }
    out.color = ui.Color(source.value);
    final shader = _shader(gradient);
    if (shader != null) out.shader = shader;
  }

  /// Draws the fitted icon into [canvas], in physical pixels of the target
  /// square. A non-null [color] replaces every paint colour (symbols).
  void paint(ui.Canvas canvas, {ui.Color? color}) {
    var saves = 0;
    for (final command in instructions.commands) {
      switch (command.type) {
        case vg.DrawCommandType.path:
          final path = this.path(instructions.paths[command.objectId!]);
          final paint = instructions.paints[command.paintId!];
          if (paint.fill != null) {
            canvas.drawPath(path, _paint(paint, stroke: false, color: color));
          }
          if (paint.stroke != null) {
            canvas.drawPath(path, _paint(paint, stroke: true, color: color));
          }
        case vg.DrawCommandType.saveLayer:
          final alpha =
              ((instructions.paints[command.paintId!].fill?.color.value ??
                      0xFF000000) >>
                  24) &
              0xFF;
          canvas.saveLayer(
            null,
            ui.Paint()..color = ui.Color.fromARGB(alpha, 0, 0, 0),
          );
          saves++;
        case vg.DrawCommandType.clip:
          canvas
            ..save()
            ..clipPath(path(instructions.paths[command.objectId!]));
          saves++;
        case vg.DrawCommandType.restore:
          if (saves > 0) {
            canvas.restore();
            saves--;
          }
        case vg.DrawCommandType.vertices:
        case vg.DrawCommandType.mask:
        case vg.DrawCommandType.text:
        case vg.DrawCommandType.image:
        case vg.DrawCommandType.pattern:
        case vg.DrawCommandType.textPosition:
          break;
      }
    }
    for (; saves > 0; saves--) {
      canvas.restore();
    }
  }

  /// Records the fitted icon as a picture of the target square.
  ui.Picture record({ui.Color? color}) {
    final recorder = ui.PictureRecorder();
    paint(ui.Canvas(recorder), color: color);
    return recorder.endRecording();
  }
}
