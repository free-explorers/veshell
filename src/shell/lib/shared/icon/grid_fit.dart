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
/// Grid fitting keeps the exact size and moves geometry instead, the way font
/// hinters do, independently on each axis:
/// - every straight horizontal or vertical edge is found, with the side its
///   ink is on, and edges are paired into stems: a pin, a bar, the thickness
///   of a frame or a ring, a stroke;
/// - each stem gets one width, its original width rounded to whole pixels
///   (at least one), so stems of the same width stay equal;
/// - a stem is anchored by its outer edge, the one farther from the icon's
///   centre, which moves at most half a pixel: the icon keeps its size, and
///   the inner edge takes the width rounding;
/// - positions are rounded by their distance from the centre, itself on a
///   whole or half pixel, so mirrored features land on mirrored pixels;
/// - every other point, curve control points included, is interpolated
///   between the anchors, so shapes stay continuous.
///
/// Curves and diagonals stay anti-aliased: that is what they look like at any
/// size. Gradients follow the unfitted geometry; they have no edges.

/// Edges closer than this, in pixels, form a stem whose width is preserved.
const _stemMax = 3.0;

/// A straight segment shorter than this, in pixels, is not an edge worth
/// snapping (the corner of a curve, a tiny notch).
const _edgeMinLength = 0.5;

const _epsilon = 1e-3;

/// How far from an edge its sides are probed for ink, in pixels.
const _probe = 0.25;

/// A straight horizontal or vertical edge: its position on one axis, its
/// extent on the other, and where its ink is (1: after it, -1: before it,
/// 0: unknown or both sides).
class _Edge {
  _Edge(this.pos, this.low, this.high, this.ink);

  final double pos;
  final double low;
  final double high;
  final int ink;
}

/// Rounds positions symmetrically around a centre on a whole or half pixel.
///
/// A position is rounded by its distance from the icon's exact centre, then
/// placed at that rounded distance from the grid's centre, so two mirrored
/// edges land on mirrored pixels: a symmetric icon stays symmetric even when
/// the grid's centre is not the exact one.
class _SymmetricGrid {
  _SymmetricGrid(this.center, this.exactCenter);

  /// The centre, on a whole or half pixel.
  final double center;

  /// The icon's exact centre, which mirrored edges are symmetric about.
  final double exactCenter;

  bool get halfCenter => center % 1 != 0;

  double distance(double v) => (v - exactCenter).abs();

  /// [v] on the nearest whole pixel, rounded away from the centre on a tie.
  double snap(double v) => _snapTo(v, 0);

  /// [v] on the nearest pixel centre (whole pixel + 0.5).
  double snapHalf(double v) => _snapTo(v, 0.5);

  /// [v] at the nearest `n + phase`, chosen by distance from the centre.
  double _snapTo(double v, double phase) {
    final d = v - exactCenter;
    // Offsets from the centre that land on `n + phase`.
    final shift = (phase - (center - center.floorToDouble())) % 1;
    final snapped = ((d.abs() - shift).roundToDouble() + shift).abs();
    return center + (d < 0 ? -snapped : snapped);
  }
}

/// A stroke on one axis: its centre line and its fitted width.
class _StrokeStem {
  _StrokeStem(this.center, this.width);

  final double center;
  final double width;

  /// Edges land on whole pixels when the centre line sits on a pixel centre
  /// (odd width) or a pixel boundary (even width).
  double target(_SymmetricGrid grid) =>
      width.toInt().isOdd ? grid.snapHalf(center) : grid.snap(center);
}

/// A run of adjacent stems sharing edges, from the lowest edge to the
/// highest: bars and slots, a pin, a frame's side, a ring's thickness.
///
/// A chain is fitted as a whole: its length is rounded to whole pixels and
/// shared among its pieces by largest remainder, so pieces of the same width
/// stay equal and no single piece absorbs the rounding of its neighbours.
class _Chain {
  _Chain(this.edges, this.ink);

  /// Positions of the chain's edges, ascending; piece `i` spans
  /// `edges[i]..edges[i + 1]`.
  final List<double> edges;

  /// Whether piece `i` is ink (a bar, a pin) rather than a gap.
  final List<bool> ink;

  double get low => edges.first;
  double get high => edges.last;
  double get length => high - low;
  double get middle => (low + high) / 2;

  /// Whether the chain is centred on [exactCenter] (the bar of a `+`).
  bool centredOn(double exactCenter) => (middle - exactCenter).abs() < 0.5;

  /// The rounded length a centred chain gets around [grid]'s centre: its
  /// ends sit on whole pixels only if its parity matches the centre's.
  int centredLength(_SymmetricGrid grid) {
    final pieces = edges.length - 1;
    var total = math.max(pieces, length.round());
    if (total.isOdd != grid.halfCenter) {
      total = length > total || total == pieces ? total + 1 : total - 1;
    }
    return total;
  }

  /// The design widths of the pieces.
  List<double> get _pieces => [
    for (var i = 0; i + 1 < edges.length; i++) edges[i + 1] - edges[i],
  ];

  /// The best whole-pixel widths of the pieces summing to [total], each at
  /// least one pixel, and their cost; `null` when impossible.
  ///
  /// The cost of a width is its change relative to the piece's own width,
  /// with ink counting double: a pixel is a big change to a thin slot and a
  /// small one to a wide frame, and uneven strokes show far more than uneven
  /// spaces. So pieces of the same design width stay equal and ink keeps one
  /// width. With [mirrored], mirrored pieces get the same width, so a centred
  /// chain stays symmetric. The pieces are few: an exact dynamic program over
  /// widths within a pixel of each design width finds the optimum.
  (List<int>, double)? _distribute(int total, {required bool mirrored}) {
    final pieces = _pieces;
    final n = pieces.length;
    final units = mirrored
        ? [
            for (var i = 0; i < n ~/ 2; i++) [i, n - 1 - i],
            if (n.isOdd) [n ~/ 2],
          ]
        : [
            for (var i = 0; i < n; i++) [i],
          ];
    double error(int i, int width) =>
        (ink[i] ? 2 : 1) * (width - pieces[i]).abs() / pieces[i];

    // best[k][sum]: the cheapest cost of the first k units summing to sum.
    final best = List.generate(units.length + 1, (_) => <int, double>{});
    final choice = List.generate(units.length + 1, (_) => <int, int>{});
    best[0][0] = 0;
    for (var k = 0; k < units.length; k++) {
      final unit = units[k];
      final low = unit
          .map((i) => math.max(1, pieces[i].floor() - 1))
          .reduce(math.max);
      final high = unit.map((i) => pieces[i].ceil() + 1).reduce(math.min);
      for (final MapEntry(key: sum, value: cost) in best[k].entries) {
        for (var width = low; width <= math.max(low, high); width++) {
          final next = sum + width * unit.length;
          if (next > total) break;
          final added = unit.fold<double>(0, (c, i) => c + error(i, width));
          final candidate = cost + added;
          if (candidate < (best[k + 1][next] ?? double.infinity)) {
            best[k + 1][next] = candidate;
            choice[k + 1][next] = width;
          }
        }
      }
    }
    final cost = best[units.length][total];
    if (cost == null) return null;
    final out = List<int>.filled(n, 1);
    var sum = total;
    for (var k = units.length; k > 0; k--) {
      final width = choice[k][sum]!;
      for (final i in units[k - 1]) {
        out[i] = width;
      }
      sum -= width * units[k - 1].length;
    }
    return (out, cost);
  }

  /// [_distribute] with the feasible total closest to [total].
  (List<int>, double) distribute(int total, {required bool mirrored}) {
    final minimum = edges.length - 1;
    for (var step = 0; step < 8; step++) {
      for (final candidate in {total + step, total - step}) {
        if (candidate < minimum) continue;
        final result = _distribute(candidate, mirrored: mirrored);
        if (result != null) return result;
      }
    }
    // Not reached in practice: plain rounding always distributes.
    return ([for (final w in _pieces) math.max(1, w.round())], double.infinity);
  }

  /// Adds the targets of the chain's edges to [anchors].
  void fit(
    _SymmetricGrid grid,
    double exactCenter,
    Map<double, double> anchors,
  ) {
    if (centredOn(exactCenter)) {
      final (widths, _) = distribute(centredLength(grid), mirrored: true);
      final total = widths.fold<int>(0, (a, b) => a + b);
      var position = grid.center - total / 2;
      for (var i = 0; i < edges.length; i++) {
        anchors[edges[i]] = position;
        if (i < widths.length) position += widths[i];
      }
      return;
    }
    // Anchor the outer end, the one farther from the centre, and walk
    // inwards: the icon's silhouette stays where it is.
    final total = math.max(edges.length - 1, length.round());
    final (widths, _) = distribute(total, mirrored: false);
    final fromHigh = grid.distance(high) >= grid.distance(low);
    if (fromHigh) {
      var position = grid.snap(high);
      for (var i = edges.length - 1; i >= 0; i--) {
        anchors[edges[i]] = position;
        if (i > 0) position -= widths[i - 1];
      }
    } else {
      var position = grid.snap(low);
      for (var i = 0; i < edges.length; i++) {
        anchors[edges[i]] = position;
        if (i < widths.length) position += widths[i];
      }
    }
  }
}

/// One axis of the fit: a monotonic, piecewise-linear map through the snapped
/// anchors.
class AxisFit {
  /// Builds the map from anchors: original position -> target.
  ///
  /// The map never folds over itself: an anchor never crosses the previous
  /// one, and edges at least half a pixel apart stay at least a pixel apart,
  /// so no visible gap or stem collapses.
  factory AxisFit(Map<double, double> anchors) {
    final from = anchors.keys.toList()..sort();
    final to = <double>[];
    for (var i = 0; i < from.length; i++) {
      var target = anchors[from[i]]!;
      if (i > 0) {
        final gap = from[i] - from[i - 1];
        final minimum = to[i - 1] + (gap >= 0.5 ? 1 : 0);
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

  /// The path of [path] in target pixels, unfitted: for ink tests.
  ui.Path _rawPath(vg.Path path) {
    final out = ui.Path()
      ..fillType = path.fillType == vg.PathFillType.evenOdd
          ? ui.PathFillType.evenOdd
          : ui.PathFillType.nonZero;
    for (final c in path.commands) {
      if (c is vg.MoveToCommand) {
        out.moveTo(_px(c.x), _py(c.y));
      } else if (c is vg.LineToCommand) {
        out.lineTo(_px(c.x), _py(c.y));
      } else if (c is vg.CubicToCommand) {
        out.cubicTo(
          _px(c.x1),
          _py(c.y1),
          _px(c.x2),
          _py(c.y2),
          _px(c.x3),
          _py(c.y3),
        );
      } else if (c is vg.CloseCommand) {
        out.close();
      }
    }
    return out;
  }

  void _collectAnchors() {
    final xs = <_Edge>[];
    final ys = <_Edge>[];
    final xStrokes = <_StrokeStem>[];
    final yStrokes = <_StrokeStem>[];
    for (final command in instructions.commands) {
      if (command.type != vg.DrawCommandType.path &&
          command.type != vg.DrawCommandType.clip) {
        continue;
      }
      final vgPath = instructions.paths[command.objectId!];
      final stroke = command.paintId == null
          ? null
          : instructions.paints[command.paintId!].stroke;
      final hasFill =
          command.type == vg.DrawCommandType.clip ||
          command.paintId == null ||
          instructions.paints[command.paintId!].fill != null;
      final raw = hasFill ? _rawPath(vgPath) : null;

      // A straight edge at [pos] on one axis, spanning [a]..[b] on the other.
      void edge({
        required bool vertical,
        required double pos,
        required double a,
        required double b,
      }) {
        final low = math.min(a, b);
        final high = math.max(a, b);
        if (stroke != null) {
          // A stroke is a stem of its own width around its centre line.
          (vertical ? xStrokes : yStrokes).add(
            _StrokeStem(pos, strokeWidth(stroke.width)),
          );
        }
        if (raw == null) return;
        // Which side is ink: probe just before and after the edge, halfway
        // along it.
        final middle = (low + high) / 2;
        bool inside(double at) => raw.contains(
          vertical ? ui.Offset(at, middle) : ui.Offset(middle, at),
        );
        final before = inside(pos - _probe);
        final after = inside(pos + _probe);
        final ink = after && !before
            ? 1
            : before && !after
            ? -1
            : 0;
        (vertical ? xs : ys).add(_Edge(pos, low, high, ink));
      }

      double? startX;
      double? startY;
      double? lastX;
      double? lastY;
      for (final c in vgPath.commands) {
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
          // visible edge of a rounded shape (the top of a ring).
          final cx = _px(c.x2);
          final cy = _py(c.y2);
          if ((cy - ny).abs() < _epsilon && (cx - nx).abs() > _epsilon) {
            edge(vertical: false, pos: ny, a: nx - 0.5, b: nx + 0.5);
          }
          if ((cx - nx).abs() < _epsilon && (cy - ny).abs() > _epsilon) {
            edge(vertical: true, pos: nx, a: ny - 0.5, b: ny + 0.5);
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
          edge(vertical: false, pos: ny, a: lastX, b: nx);
        }
        if ((nx - lastX).abs() < _epsilon &&
            (ny - lastY).abs() >= _edgeMinLength) {
          edge(vertical: true, pos: nx, a: lastY, b: ny);
        }
        lastX = nx;
        lastY = ny;
      }
    }
    x = AxisFit(_fitAxis(xs, xStrokes));
    y = AxisFit(_fitAxis(ys, yStrokes));
  }

  /// Targets for one axis: chains of stems, outermost first, then strokes,
  /// then lone edges.
  Map<double, double> _fitAxis(List<_Edge> edges, List<_StrokeStem> strokes) {
    // Pair each edge with the nearest edge after it of the opposite kind,
    // overlapping it on the other axis: where ink starts and then ends is a
    // filled stem (a pin, a bar); where ink ends and then starts again is a
    // gap (a slot, the space between pins). Gaps are kept whole-pixel and
    // even too: font hinters control white distances as well as black ones.
    edges.sort((a, b) => a.pos.compareTo(b.pos));
    final links = <double, Set<double>>{};
    final inkBetween = <(double, double), bool>{};
    for (final startInk in const [1, -1]) {
      final used = <_Edge>{};
      for (final start in edges.where((e) => e.ink == startInk)) {
        if (used.contains(start)) continue;
        for (final end in edges) {
          if (end.pos <= start.pos + _epsilon) continue;
          if (end.pos - start.pos > _stemMax) break;
          if (end.ink != -startInk || used.contains(end)) continue;
          if (end.high < start.low || end.low > start.high) continue;
          used
            ..add(start)
            ..add(end);
          (links[start.pos] ??= {}).add(end.pos);
          inkBetween[(start.pos, end.pos)] = startInk == 1;
          (links[end.pos] ??= {}).add(start.pos);
          break;
        }
      }
    }

    // Stems sharing an edge form a chain. A run that branches (an edge
    // linked to two stems on the same side) is split into simple chains.
    final chains = <_Chain>[];
    final visited = <double>{};
    for (final start in links.keys.toList()..sort()) {
      if (visited.contains(start)) continue;
      final lower = links[start]!.where((p) => p < start);
      if (lower.isNotEmpty && !visited.containsAll(lower)) continue;
      final run = <double>[start];
      visited.add(start);
      var current = start;
      while (true) {
        final next = links[current]!.where((p) => p > current).toList()..sort();
        if (next.isEmpty || visited.contains(next.first)) break;
        current = next.first;
        run.add(current);
        visited.add(current);
      }
      if (run.length > 1) {
        chains.add(
          _Chain(run, [
            for (var i = 0; i + 1 < run.length; i++)
              inkBetween[(run[i], run[i + 1])] ?? true,
          ]),
        );
      }
    }

    // The centre sits on a whole or half pixel: whichever, among those
    // within half a pixel of the exact centre, lets centred chains keep the
    // width closest to their own (the bars of a `+` stay 2 pixels rather
    // than 3), and the nearest otherwise.
    final exactCenter = pixels / 2;
    final candidates =
        {
          for (final c in [
            exactCenter.floorToDouble(),
            exactCenter.floorToDouble() + 0.5,
            exactCenter.ceilToDouble(),
          ])
            if ((c - exactCenter).abs() <= 0.5) c,
        }.toList()..sort(
          (a, b) => (a - exactCenter).abs().compareTo((b - exactCenter).abs()),
        );
    double cost(double center) {
      final grid = _SymmetricGrid(center, exactCenter);
      return chains
          .where((chain) => chain.centredOn(exactCenter))
          .fold<double>(
            0,
            (sum, chain) =>
                sum +
                chain.distribute(chain.centredLength(grid), mirrored: true).$2,
          );
    }

    var center = candidates.first;
    for (final candidate in candidates.skip(1)) {
      if (cost(candidate) < cost(center) - _epsilon) center = candidate;
    }
    final grid = _SymmetricGrid(center, exactCenter);

    final anchors = <double, double>{};
    chains.sort(
      (a, b) => math
          .max(grid.distance(b.low), grid.distance(b.high))
          .compareTo(math.max(grid.distance(a.low), grid.distance(a.high))),
    );
    for (final chain in chains) {
      chain.fit(grid, exactCenter, anchors);
    }
    for (final stroke in strokes) {
      anchors.putIfAbsent(stroke.center, () => stroke.target(grid));
    }
    for (final edge in edges) {
      anchors.putIfAbsent(edge.pos, () => grid.snap(edge.pos));
    }
    return anchors;
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
