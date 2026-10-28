import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/icon/glyph_outlines.dart';
import 'package:shell/shared/icon/grid_fit.dart';
import 'package:shell/shared/icon/grid_fitted_vector.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

/// The MDI `plus` glyph as the font stores it: its bars are 1.97 units wide
/// and their edges (11.016, 12.984) sit between pixels at any scale.
const _plus =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path d="M18.984 12.984H12.984V18.984H11.016V12.984H5.016V11.016'
    'H11.016V5.016H12.984V11.016H18.984Z"/></svg>';

/// Pixels of [fit] rendered white on transparent, as alpha values.
Future<(int, Uint8List)> _render(GridFit fit) async {
  final pixels = fit.pixels.ceil();
  final picture = fit.record(color: const ui.Color(0xFFFFFFFF));
  final image = await picture.toImage(pixels, pixels);
  final bytes = await image.toByteData();
  final rgba = bytes!.buffer.asUint8List();
  return (
    pixels,
    Uint8List.fromList([for (var i = 3; i < rgba.length; i += 4) rgba[i]]),
  );
}

/// Every x (or y) where a fitted path has a vertical (or horizontal) edge.
Set<double> _edges(GridFit fit, {required bool vertical}) {
  final edges = <double>{};
  for (final path in fit.instructions.paths) {
    ui.Offset? last;
    ui.Offset? start;
    for (final c in path.commands) {
      ui.Offset? point;
      if (c is vg.MoveToCommand) {
        last = start = fit.point(c.x, c.y);
        continue;
      }
      if (c is vg.LineToCommand) point = fit.point(c.x, c.y);
      // The closing segment is an edge too (the plus's right side).
      if (c is vg.CloseCommand) point = start;
      if (point != null && last != null) {
        if (vertical && (point.dx - last.dx).abs() < 1e-6) edges.add(point.dx);
        if (!vertical && (point.dy - last.dy).abs() < 1e-6) {
          edges.add(point.dy);
        }
      }
      last = point ?? last;
    }
  }
  return edges;
}

void main() {
  group('AxisFit', () {
    test('snaps anchors and interpolates between them', () {
      final fit = AxisFit({10.3: 10, 20.6: 21});
      expect(fit(10.3), 10);
      expect(fit(20.6), 21);
      // Halfway between the anchors stays halfway between their targets.
      expect(fit(15.45), closeTo(15.5, 1e-9));
      // Outside the anchors, the nearest anchor's shift applies.
      expect(fit(5), closeTo(4.7, 1e-9));
    });

    test('keeps a stem width consistent, rounded to whole pixels', () {
      // Two bars 2.36 px wide: each keeps 2 px, wherever its edges round.
      final fit = AxisFit({13.22: 13, 15.58: 16, 20.22: 20, 22.58: 23});
      expect(fit(15.58) - fit(13.22), 2);
      expect(fit(22.58) - fit(20.22), 2);
    });

    test('never collapses a visible gap', () {
      // 0.6 px apart, both rounding to 10: they stay a pixel apart.
      final fit = AxisFit({9.8: 10, 10.4: 10});
      expect(fit(10.4) - fit(9.8), greaterThanOrEqualTo(1));
    });
  });

  group('GridFit', () {
    final plus = vg.parseWithoutOptimizers(_plus);

    test('puts every straight edge on a whole pixel', () {
      final fit = GridFit(plus, 28.8);
      for (final edge in {
        ..._edges(fit, vertical: true),
        ..._edges(fit, vertical: false),
      }) {
        expect(edge, closeTo(edge.roundToDouble(), 1e-9));
      }
    });

    test('keeps the size: outer edges move at most half a pixel', () {
      final fitted = GridFit(plus, 28.8);
      final exact = GridFit(plus, 28.8, fit: false);
      for (final vertical in [true, false]) {
        final a = _edges(fitted, vertical: vertical).toList()..sort();
        final b = _edges(exact, vertical: vertical).toList()..sort();
        expect(a.length, b.length);
        // The icon's extent is its size: within half a pixel.
        expect(a.first, closeTo(b.first, 0.5 + 1e-9));
        expect(a.last, closeTo(b.last, 0.5 + 1e-9));
        // Inner edges may move further so a stem keeps a whole-pixel width
        // (a 2.36 px bar becomes 2 px), but never more than a pixel.
        for (var i = 0; i < a.length; i++) {
          expect(a[i], closeTo(b[i], 1 + 1e-9));
        }
      }
    });

    test('gives both bars of a plus the same width', () {
      final fit = GridFit(plus, 28.8);
      final xs = _edges(fit, vertical: true).toList()..sort();
      final ys = _edges(fit, vertical: false).toList()..sort();
      // Bar edges are the two middle values on each axis.
      expect(xs[2] - xs[1], ys[2] - ys[1]);
    });

    test('renders crisp bars at a fractional size', () async {
      // The vertical bar's pixel columns are fully on or fully off, outside
      // the arm ends: no column is a fringe.
      final (size, alpha) = await _render(GridFit(plus, 28.8));
      final row = size ~/ 4; // through the top arm only
      final columns = [for (var x = 0; x < size; x++) alpha[row * size + x]];
      expect(columns.where((a) => a == 255), hasLength(2));
      expect(columns.where((a) => a != 0 && a != 255), isEmpty);
    });

    test('was soft without fitting (the problem being fixed)', () async {
      final (size, alpha) = await _render(GridFit(plus, 28.8, fit: false));
      final row = size ~/ 4;
      final columns = [for (var x = 0; x < size; x++) alpha[row * size + x]];
      expect(columns.where((a) => a != 0 && a != 255), isNotEmpty);
    });

    test('centres an odd-width stroke on a pixel centre', () {
      final line = vg.parseWithoutOptimizers(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<path d="M4.3 12.2H19.7" stroke="#000" stroke-width="0.8" '
        'fill="none"/></svg>',
      );
      final fit = GridFit(line, 28.8);
      expect(fit.strokeWidth(0.8), 1);
      final y = _edges(fit, vertical: false).single;
      expect(y - y.floorToDouble(), closeTo(0.5, 1e-9));
    });

    test('leaves unsupported SVG features to the regular renderer', () {
      expect(isGridFittable(plus), isTrue);
      final text = vg.parseWithoutOptimizers(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
        '<text x="2" y="20" font-size="10">A</text></svg>',
      );
      expect(isGridFittable(text), isFalse);
    });
  });

  group('GlyphOutlines and ShellIcon', () {
    // The real font and FontManifest.json, from the test asset bundle: the
    // same lookup the shell does at runtime.
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      GlyphOutlines.instance.reset();
    });

    test('reads a glyph from the icon font', () async {
      final glyph = await GlyphOutlines.instance.outline(MdiIcons.plus);
      expect(glyph, isNotNull);
      // The em box `Icon` lays the glyph out in: 512 by 512 units.
      expect(glyph!.width, 512);
      expect(glyph.height, 512);
      expect(isGridFittable(glyph), isTrue);
      // A second lookup is synchronous.
      expect(GlyphOutlines.instance.outline(MdiIcons.plus), same(glyph));
    });

    test('a missing glyph yields null', () async {
      const missing = IconData(
        0x10FFF0,
        fontFamily: 'Material Design Icons',
        fontPackage: 'material_design_icons_flutter',
      );
      expect(await GlyphOutlines.instance.outline(missing), isNull);
    });

    testWidgets('ShellIcon draws the glyph grid-fitted with the icon theme', (
      tester,
    ) async {
      Widget icon() => const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: IconTheme(
            data: IconThemeData(size: 30, color: Color(0xFF00FF00)),
            child: ShellIcon(MdiIcons.plus),
          ),
        ),
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(icon());
        await GlyphOutlines.instance.outline(MdiIcons.plus);
      });
      await tester.pump();
      final vector = tester.widget<GridFittedVector>(
        find.byType(GridFittedVector),
      );
      expect(vector.size, 30);
      expect(vector.color, const Color(0xFF00FF00));
      expect(tester.getSize(find.byType(ShellIcon)), const Size.square(30));
    });

    testWidgets('ShellIcon falls back to Icon for a glyph it cannot read', (
      tester,
    ) async {
      const missing = IconData(
        0x10FFF0,
        fontFamily: 'Material Design Icons',
        fontPackage: 'material_design_icons_flutter',
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: ShellIcon(missing, size: 20),
          ),
        );
        await GlyphOutlines.instance.outline(missing);
      });
      await tester.pump();
      expect(find.byType(GridFittedVector), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
