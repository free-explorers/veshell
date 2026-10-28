import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/shared/icon/glyph_outlines.dart';
import 'package:shell/shared/widget/shell_icon.dart';

/// The bounding box of the opaque pixels under [key], rendered at [ratio].
Future<Rect?> _inkBox(GlobalKey key, double ratio) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: ratio);
  final bytes = (await image.toByteData())!.buffer.asUint8List();
  int? left;
  int? top;
  int? right;
  int? bottom;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      // Above half coverage: ignores the anti-aliased fringe that differs
      // between a text glyph and a grid-fitted one.
      if (bytes[(y * image.width + x) * 4 + 3] < 128) continue;
      left = left == null || x < left ? x : left;
      right = right == null || x > right ? x : right;
      top ??= y;
      bottom = y;
    }
  }
  if (left == null) return null;
  return Rect.fromLTRB(
    left.toDouble(),
    top!.toDouble(),
    right!.toDouble(),
    bottom!.toDouble(),
  );
}

/// Layouts that force an icon's box away from its size.
final _layouts = <String, Widget Function(Widget icon)>{
  'unconstrained': (icon) => icon,
  'a tight 48-pixel box': (icon) => SizedBox.square(dimension: 48, child: icon),
  'an InputDecoration suffix icon': (icon) => SizedBox(
    width: 200,
    child: TextField(decoration: InputDecoration(suffixIcon: icon)),
  ),
  'an IconButton': (icon) => IconButton(onPressed: () {}, icon: icon),
};

void main() {
  const ratio = 1.2;

  testWidgets('ShellIcon covers the same pixels as Icon in every layout', (
    tester,
  ) async {
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.resetDevicePixelRatio);
    const icons = {
      'plus': MdiIcons.plus,
      'pencil': MdiIcons.pencil,
      'close': MdiIcons.close,
    };
    // Icon needs the real font to draw its glyph; ShellIcon its outline.
    await tester.runAsync(() async {
      final loader =
          FontLoader(
            'packages/material_design_icons_flutter/Material Design Icons',
          )..addFont(
            rootBundle.load(
              'packages/material_design_icons_flutter/lib/fonts/'
              'materialdesignicons-webfont.ttf',
            ),
          );
      await loader.load();
      for (final icon in icons.values) {
        await GlyphOutlines.instance.outline(icon);
      }
    });

    for (final MapEntry(key: layout, value: wrap) in _layouts.entries) {
      for (final MapEntry(key: name, value: icon) in icons.entries) {
        for (final size in [null, 20.0]) {
          final reference = GlobalKey();
          final shell = GlobalKey();
          Widget slot(GlobalKey key, Widget icon) => RepaintBoundary(
            key: key,
            child: Material(type: MaterialType.transparency, child: wrap(icon)),
          );
          await tester.pumpWidget(
            MaterialApp(
              home: IconTheme(
                data: const IconThemeData(color: Color(0xFFFFFFFF)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    slot(reference, Icon(icon, size: size)),
                    slot(shell, ShellIcon(icon, size: size)),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();
          final what = '$name (size $size) in $layout';
          expect(
            tester.getSize(find.byKey(shell)),
            tester.getSize(find.byKey(reference)),
            reason: 'layout size of $what',
          );
          final (expected, actual) = (await tester.runAsync(
            () async =>
                (await _inkBox(reference, ratio), await _inkBox(shell, ratio)),
          ))!;
          expect(actual, isNotNull, reason: what);
          for (final (edge, a, b) in [
            ('left', actual!.left, expected!.left),
            ('top', actual.top, expected.top),
            ('right', actual.right, expected.right),
            ('bottom', actual.bottom, expected.bottom),
          ]) {
            expect(a, closeTo(b, 1), reason: '$edge edge of $what');
          }
        }
      }
    }
  });
}
