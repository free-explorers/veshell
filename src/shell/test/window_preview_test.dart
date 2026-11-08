import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/meta_window/provider/meta_window_state.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/model/request/window_preview/window_preview.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/systemd/provider/session_guard.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_preview_path.dart';
import 'package:shell/window/model/window_properties.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';
import 'package:shell/window/provider/window_preview_image.dart';

const _tile = PersistentWindowId('tile-preview');
const _metaWindow = 'meta-preview';

class _FakePlatformManager extends PlatformManager {
  final requests = <PlatformRequest>[];

  @override
  Stream<PlatformEvent> build() => const Stream.empty();

  @override
  Future<void> request(PlatformRequest request) async => requests.add(request);
}

class _FixedMetaWindowState extends MetaWindowState {
  _FixedMetaWindowState(this.window);

  final MetaWindow window;

  @override
  MetaWindow build(String id) => window;
}

class _TestPersistentWindowState extends PersistentWindowState {
  _TestPersistentWindowState(this.initial);

  final PersistentWindow initial;

  @override
  PersistentWindow build(PersistentWindowId windowId) => initial;
}

MetaWindow _window() => const MetaWindow(
  id: _metaWindow,
  pid: 1,
  mapped: true,
  surfaceId: 0,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  appId: 'code-oss',
  title: 'Preview',
);

PersistentWindow _tileWindow() => const PersistentWindow(
  windowId: _tile,
  properties: WindowProperties(appId: 'code-oss', title: 'Preview'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a persisted window frame bakes into a blurred preview', () async {
    final directory = Directory.systemTemp.createTempSync('veshell_preview_');
    addTearDown(() {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 120, 80),
      ui.Paint()..color = const ui.Color(0xFF336699),
    );
    final picture = recorder.endRecording();
    final source = await picture.toImage(120, 80);
    final png = await source.toByteData(format: ui.ImageByteFormat.png);
    source.dispose();
    picture.dispose();
    expect(png, isNotNull);
    File(
      windowPreviewPath(_tile, directory),
    ).writeAsBytesSync(png!.buffer.asUint8List());
    await writeWindowPreviewLayout(
      _tile,
      directory,
      size: const ui.Size(120, 80),
      fullBleed: false,
    );

    final container = ProviderContainer(
      overrides: [windowPreviewDirectoryProvider.overrideWithValue(directory)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      windowPreviewImageProvider(_tile),
      (_, _) {},
    );
    addTearDown(subscription.close);

    final baked = await container.read(
      windowPreviewImageProvider(_tile).future,
    );
    expect(baked, isNotNull);
    expect((baked!.image.width, baked.image.height), (120, 80));
    expect(baked.layout?.size, const ui.Size(120, 80));
    expect(baked.layout?.fullBleed, isFalse);
  });

  test('a tile without a persisted frame has no preview', () async {
    final directory = Directory.systemTemp.createTempSync('veshell_preview_');
    addTearDown(() {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    });
    final container = ProviderContainer(
      overrides: [windowPreviewDirectoryProvider.overrideWithValue(directory)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      windowPreviewImageProvider(_tile),
      (_, _) {},
    );
    addTearDown(subscription.close);

    expect(
      await container.read(windowPreviewImageProvider(_tile).future),
      isNull,
    );
  });

  test('a displayed window binds and clears its tile preview', () {
    final platform = _FakePlatformManager();
    final tile = _TestPersistentWindowState(_tileWindow());
    final container = ProviderContainer(
      overrides: [
        platformManagerProvider.overrideWith(() => platform),
        prepareForShutdownSignalsProvider.overrideWith(
          (ref) => const Stream<bool>.empty(),
        ),
        metaWindowStateProvider(
          _metaWindow,
        ).overrideWith(() => _FixedMetaWindowState(_window())),
        persistentWindowStateProvider(_tile).overrideWith(() => tile),
      ],
    );
    addTearDown(container.dispose);
    container.listen(sessionGuardProvider, (_, _) {});

    final notifier = container.read(
      persistentWindowStateProvider(_tile).notifier,
    )..initialize(_tileWindow().copyWith(metaWindowId: _metaWindow));

    final previews = platform.requests
        .whereType<WindowPreviewRequest>()
        .toList();
    expect(previews, hasLength(1));
    final attached = previews.single.message! as WindowPreviewMessage;
    expect(attached.metaWindowId, _metaWindow);
    expect(attached.persistentWindowId, _tile.uuid);
    expect(attached.attach, isTrue);

    notifier.onCurrentlyDisplayedMetaWindowChanged(null);

    final cleared =
        platform.requests.whereType<WindowPreviewRequest>().last.message!
            as WindowPreviewMessage;
    expect(cleared.metaWindowId, _metaWindow);
    expect(cleared.persistentWindowId, _tile.uuid);
    expect(cleared.attach, isFalse);
  });
}
