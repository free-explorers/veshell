import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/application/widget/grid_fit_svg_icon.dart';

/// A [size] x [size] opaque PNG, encoded by the engine.
Future<List<int>> _pngBytes(WidgetTester tester, int size) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF3366CC),
    );
    final image = await recorder.endRecording().toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// Pumps an [AppIconByPath] resolving to a [pixels]-wide PNG in a [box]
/// logical-pixel box, at a device pixel ratio of one.
Future<void> _pumpRasterIcon(
  WidgetTester tester, {
  required int pixels,
  required double box,
}) async {
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final directory = Directory.systemTemp.createTempSync('app-icon-test');
  addTearDown(() => directory.deleteSync(recursive: true));
  final png = File('${directory.path}/icon.png')
    ..writeAsBytesSync(await _pngBytes(tester, pixels));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        iconFileFromQueryProvider.overrideWith((ref, query) async => png),
      ],
      child: MaterialApp(
        home: Center(
          child: SizedBox(
            width: box,
            height: box,
            child: const AppIconByPath(path: 'legacy', title: 'Legacy'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('panel-sized SVG icon is displayed after a cold lookup', (
    tester,
  ) async {
    // A 1:1 device pixel ratio keeps the computed decode bucket predictable.
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final directory = Directory.systemTemp.createTempSync('app-icon-test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final svg = File('${directory.path}/icon.svg')
      ..writeAsStringSync('''
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">
  <circle cx="12" cy="12" r="10" fill="white"/>
</svg>
''');
    final lookup = Completer<File?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Override the whole family: the widget asks for a physical-pixel
          // bucket, not a raw logical size.
          iconFileFromQueryProvider.overrideWith((ref, query) => lookup.future),
        ],
        child: const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: AppIconByPath(path: 'com.obsproject.Studio'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(GridFitSvgIcon), findsNothing);

    lookup.complete(svg);
    await tester.pumpAndSettle();
    // SVG icons are drawn grid-fitted (flutter_svg is their fallback).
    expect(find.byType(GridFitSvgIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('raster icons use a bounded decode size', (tester) async {
    await _pumpRasterIcon(tester, pixels: 64, box: 24);

    expect(tester.widget<Image>(find.byType(Image)).image, isA<ResizeImage>());
    expect(
      (tester.widget<Image>(find.byType(Image)).image as ResizeImage).width,
      24,
    );
    expect(find.byType(DecoratedBox), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a raster icon slightly too small fills the box', (tester) async {
    // 48 px in a 56 px box: past 70 %, a mild upscale.
    await _pumpRasterIcon(tester, pixels: 48, box: 56);

    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    expect(find.byType(DecoratedBox), findsNothing);
  });

  testWidgets('a much smaller raster icon sits unscaled on a plate', (
    tester,
  ) async {
    // 48 px in a 96 px box would be stretched twofold.
    await _pumpRasterIcon(tester, pixels: 48, box: 96);

    expect(tester.getSize(find.byType(Image)), const Size(48, 48));
    final plate = find.ancestor(
      of: find.byType(Image),
      matching: find.byType(DecoratedBox),
    );
    expect(tester.getSize(plate.first), const Size(96, 96));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing icon falls back to the application initial', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iconFileFromQueryProvider.overrideWith((ref, query) async => null),
        ],
        child: const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: AppIconByPath(path: 'missing', title: 'Files'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an entry without an icon uses the application initial', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iconFileFromQueryProvider.overrideWith(
            (ref, query) => fail('No icon lookup is expected'),
          ),
        ],
        child: const MaterialApp(
          home: Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: AppIconByPath(path: null, title: 'Alacritty'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Al'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
