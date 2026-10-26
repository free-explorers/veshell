import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/shared/util/file.dart';
import 'package:shell/systemd/provider/session_guard.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';

/// A minimal displayed window used to drive the persisted-properties path.
MetaWindow _metaWindow(String title) => MetaWindow(
  id: 'meta-window',
  pid: 42,
  mapped: true,
  surfaceId: 1,
  needDecoration: false,
  gameModeActivated: false,
  scaleRatio: 1,
  appId: 'firefox',
  title: title,
);

void main() {
  const windowId = PersistentWindowId('abc');

  late Directory directory;
  late ProviderContainer container;
  late ProviderSubscription<PersistentWindow> windowSubscription;
  late SessionGuard guard;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync(
      'veshell_teardown_persistence_',
    );
    // A legacy file so the test also exercises the migration path that the
    // resume-state work will rely on.
    File('${directory.path}/persistent_window_abc.json').writeAsStringSync(
      jsonEncode({
        'windowId': {'uuid': 'abc', 'runtimeType': 'persistent'},
        'properties': {'appId': 'firefox', 'title': 'before'},
        'metaWindowId': null,
        'isWaitingForSurface': false,
        'displayMode': 'maximized',
        'customExec': null,
        'pid': null,
      }),
    );

    container = ProviderContainer(
      overrides: [
        persistenceDirectoryProvider.overrideWithValue(directory),
        prepareForShutdownSignalsProvider.overrideWith(
          (ref) => const Stream<bool>.empty(),
        ),
      ],
    );
    await container.read(persistentStorageStateProvider.future);
    container.listen(sessionGuardProvider, (_, _) {});
    guard = container.read(sessionGuardProvider.notifier);

    windowSubscription = container.listen(
      persistentWindowStateProvider(windowId),
      (_, _) {},
    );
  });

  tearDown(() {
    windowSubscription.close();
    container.dispose();
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  String persistedTitle() {
    final file = File('${directory.path}/persistent_window_abc.json');
    final raw = jsonDecode(file.readAsStringSync()) as Map;
    final data = raw['data'] as Map;
    final properties = data['properties'] as Map;
    return properties['title'] as String;
  }

  test(
    'window properties update normally while the session is running',
    () async {
      final notifier = container.read(
        persistentWindowStateProvider(windowId).notifier,
      );

      notifier.onMetaWindowDisplayedPropertiesChanged(_metaWindow('after'));
      await flushPendingWrites();

      expect(persistedTitle(), 'after');
    },
  );

  test('teardown window events do not overwrite the last state', () async {
    final notifier = container.read(
      persistentWindowStateProvider(windowId).notifier,
    );

    await guard.beginLeaving();
    notifier.onMetaWindowDisplayedPropertiesChanged(_metaWindow('teardown'));
    await flushPendingWrites();

    expect(persistedTitle(), 'before');

    // A cancelled shutdown resumes normal persistence.
    guard.cancelLeaving();
    notifier.onMetaWindowDisplayedPropertiesChanged(_metaWindow('after'));
    await flushPendingWrites();

    expect(persistedTitle(), 'after');
  });
}
