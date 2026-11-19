import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/util/symbolic_svg.dart';
import 'package:shell/application/widget/grid_fit_svg_icon.dart';
import 'package:shell/shared/icon/grid_fitted_vector.dart';

/// Adwaita's symbolic style: a dark placeholder fill, `-symbolic` name.
const _adwaita =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"> '
    '<path d="M2 2h12v12H2z" fill="#2e3436"/></svg>';

/// Breeze's style: `currentColor` under the `ColorScheme-Text` class.
const _breeze = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 22 22">
<defs><style type="text/css" id="current-color-scheme">
.ColorScheme-Text { color:#232629; }
</style></defs>
<path style="fill:currentColor" class="ColorScheme-Text" d="M3 3h16v16H3z"/>
</svg>''';

/// A coloured application icon.
const _colourful =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"> '
    '<path d="M2 2h12v12H2z" fill="#167abf"/></svg>';

void main() {
  group('isSymbolicSvg', () {
    test('recognizes the freedesktop -symbolic name', () {
      expect(isSymbolicSvg('/a/network-wireless-symbolic.svg', _adwaita), true);
    });

    test('recognizes the KDE ColorScheme-Text convention', () {
      expect(isSymbolicSvg('/a/nm-signal-100.svg', _breeze), true);
    });

    test('leaves a coloured icon alone', () {
      expect(isSymbolicSvg('/a/code-oss.svg', _colourful), false);
      expect(isSymbolicSvg('/a/symbolic-app.svg', _colourful), false);
    });
  });

  group('GridFitSvgIcon', () {
    Future<GridFittedVector> pumpIcon(
      WidgetTester tester,
      String name,
      String svg,
    ) async {
      final directory = Directory.systemTemp.createTempSync('symbolic-svg');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/$name')..writeAsStringSync(svg);
      await tester.pumpWidget(
        MaterialApp(
          home: IconTheme(
            data: const IconThemeData(color: Color(0xFFEEEEEE)),
            child: GridFitSvgIcon(file: file, size: 16),
          ),
        ),
      );
      await tester.runAsync(() async {
        // The parse runs on another isolate.
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          tester.binding.scheduleFrame();
          await tester.pump();
          if (find.byType(GridFittedVector).evaluate().isNotEmpty) break;
        }
      });
      return tester.widget<GridFittedVector>(find.byType(GridFittedVector));
    }

    testWidgets('tints a symbolic icon with the icon theme colour', (
      tester,
    ) async {
      final vector = await pumpIcon(tester, 'nm-signal-100.svg', _breeze);
      expect(vector.color, const Color(0xFFEEEEEE));
    });

    testWidgets('keeps a coloured icon its own colours', (tester) async {
      final vector = await pumpIcon(tester, 'code-oss.svg', _colourful);
      expect(vector.color, isNull);
    });
  });
}
