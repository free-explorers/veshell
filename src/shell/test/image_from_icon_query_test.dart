import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/icon_themes.dart';
import 'package:shell/application/provider/image_from_icon_query.dart';

/// A 1x1 PNG, enough for `instantiateImageCodec` to produce a native
/// [ui.Image].
const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAABHNCSVQICAgIfAhkiAAA'
    'AAFzUkdCAK7OHOkAAAANSURBVAiZY/jPwPAfAAUAAf+rzjaJAAAAAElFTkSuQmCC';

/// Minimal [FreedesktopIconTheme] stand-in. The real class can only be built
/// through filesystem indexing, which a unit test must not depend on.
class _FakeIconTheme implements FreedesktopIconTheme {
  _FakeIconTheme(this._findIcon);

  final Future<File?> Function(IconQuery query) _findIcon;

  @override
  Future<File?> findIcon(IconQuery query) => _findIcon(query);

  @override
  dynamic refresh() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Regression: the provider used to dispose its native image from
  // `ref.onDispose`, which Riverpod also runs before every rebuild. When the
  // icon theme resolved at session start the provider rebuilt, the image was
  // freed while the widget was still painting it, and every icon in the
  // screen panel went blank. The previous image must stay alive until the new
  // one has decoded and replaced it.
  test(
    'a rebuild keeps the previous image until the next one is decoded',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'icon-query-test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final iconFile = File('${directory.path}/icon.png');
      await iconFile.writeAsBytes(base64Decode(_onePixelPng));

      // The first lookup resolves immediately, the second one is held open so
      // the test can observe the provider mid-rebuild.
      var calls = 0;
      final secondLookup = Completer<File?>();
      final theme = _FakeIconTheme((_) {
        calls++;
        return calls == 1 ? Future.value(iconFile) : secondLookup.future;
      });

      final container = ProviderContainer(
        overrides: [iconThemesProvider.overrideWith((ref) => theme)],
      );
      addTearDown(container.dispose);

      final query = IconQuery(
        name: 'icon',
        size: 24,
        extensions: const ['png'],
      );
      const size = ui.Size(24, 24);
      final provider = imageFromIconQueryProvider(query, size);

      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final first = await container.read(provider.future);
      expect(first, isNotNull);
      expect(first!.debugDisposed, isFalse);

      // Force the same rebuild the icon theme resolution triggers at startup.
      container.invalidate(iconThemesProvider);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      // The second decode is in flight. The widget is still showing the first
      // image, so it must not have been disposed yet.
      expect(
        first.debugDisposed,
        isFalse,
        reason: 'the displayed image must survive a rebuild',
      );

      secondLookup.complete(iconFile);
      final second = await container.read(provider.future);
      expect(second, isNotNull);
      expect(second, isNot(same(first)));
      expect(second!.debugDisposed, isFalse);
      expect(
        first.debugDisposed,
        isTrue,
        reason: 'the replaced image is freed once the new one is ready',
      );
    },
  );
}
