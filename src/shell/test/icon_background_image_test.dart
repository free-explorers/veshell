import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/icon_background_image.dart';
import 'package:shell/application/provider/icon_file_from_query.dart';

/// A 1x1 PNG, enough for `instantiateImageCodec` to produce a native image.
const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAABHNCSVQICAgIfAhkiAAA'
    'AAFzUkdCAK7OHOkAAAANSURBVAiZY/jPwPAfAAUAAf+rzjaJAAAAAElFTkSuQmCC';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bakes a square background from the resolved icon file', () async {
    final directory = await Directory.systemTemp.createTemp('icon-bg-test');
    addTearDown(() => directory.delete(recursive: true));
    final png = File('${directory.path}/icon.png')
      ..writeAsBytesSync(base64Decode(_onePixelPng));

    final container = ProviderContainer(
      overrides: [
        iconFileFromQueryProvider.overrideWith((ref, query) async => png),
      ],
    );
    addTearDown(container.dispose);

    final provider = iconBackgroundImageProvider('brave-desktop');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    final image = await container.read(provider.future);
    expect(image, isNotNull);
    expect(image!.width, 64);
    expect(image.height, 64);
    expect(image.debugDisposed, isFalse);
  });

  test('resolves to null when the icon file is unknown', () async {
    final container = ProviderContainer(
      overrides: [
        iconFileFromQueryProvider.overrideWith((ref, query) async => null),
      ],
    );
    addTearDown(container.dispose);

    final provider = iconBackgroundImageProvider('missing');
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);

    expect(await container.read(provider.future), isNull);
  });
}
