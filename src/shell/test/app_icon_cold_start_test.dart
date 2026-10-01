import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';
import 'package:shell/application/widget/app_icon.dart';

void main() {
  testWidgets('panel-sized SVG icon is displayed after a cold lookup', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('app-icon-test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final svg = File('${directory.path}/icon.svg')
      ..writeAsStringSync('''
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">
  <circle cx="12" cy="12" r="10" fill="white"/>
</svg>
''');
    final lookup = Completer<File?>();
    final query = IconQuery(
      name: 'com.obsproject.Studio',
      size: 24,
      extensions: const ['svg', 'png'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iconFileFromQueryProvider(query).overrideWith((ref) => lookup.future),
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
    final directory = Directory.systemTemp.createTempSync('app-icon-test');
    addTearDown(() => directory.deleteSync(recursive: true));
    final png = File('${directory.path}/icon.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAABHNCSVQICAgIfAhkiAAA'
          'AAFzUkdCAK7OHOkAAAANSURBVAiZY/jPwPAfAAUAAf+rzjaJAAAAAElFTkSuQmCC',
        ),
      );
    final query = IconQuery(
      name: 'brave-desktop',
      size: 24,
      extensions: const ['svg', 'png'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iconFileFromQueryProvider(query).overrideWith((ref) async => png),
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
