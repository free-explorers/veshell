import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/widget/app_icon.dart';

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
    expect(find.byType(SvgPicture), findsNothing);

    lookup.complete(svg);
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('raster icons use a bounded decode size', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final directory = Directory.systemTemp.createTempSync('app-icon-test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final png = File('${directory.path}/icon.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAABHNCSVQICAgIfAhkiAAA'
          'AAFzUkdCAK7OHOkAAAANSURBVAiZY/jPwPAfAAUAAf+rzjaJAAAAAElFTkSuQmCC',
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iconFileFromQueryProvider.overrideWith((ref, query) async => png),
        ],
        child: const MaterialApp(
          home: Center(
            child: AppIconByPath(path: 'brave-desktop', constrainedSize: 24),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, isA<ResizeImage>());
    expect(
      (tester.widget<Image>(find.byType(Image)).image as ResizeImage).width,
      24,
    );
    expect(tester.takeException(), isNull);
  });
}
