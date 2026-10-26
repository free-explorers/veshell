import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/platform/model/event/process_info/process_info.serializable.dart';
import 'package:shell/shared/model/persistence_schema.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/shared/util/file.dart';
import 'package:shell/systemd/provider/session_guard.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';

void main() {
  const windowId = PersistentWindowId('abc');

  late Directory directory;
  late ProviderContainer container;
  late ProviderSubscription<PersistentWindow> windowSubscription;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('veshell_resume_state_');
    File('${directory.path}/persistent_window_abc.json').writeAsStringSync(
      jsonEncode({
        persistenceEnvelopeKey: {
          'store': PersistenceStore.persistentWindow.name,
          // Version 1 has no resume-context fields: the migration must add
          // them before the freezed decoder runs.
          'version': 1,
        },
        'data': {
          'windowId': {'uuid': 'abc', 'runtimeType': 'persistent'},
          'properties': {'appId': 'foot', 'title': '~/src'},
          'metaWindowId': null,
          'isWaitingForSurface': false,
          'displayMode': 'maximized',
          'customExec': null,
          'pid': null,
        },
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

  PersistentWindowState notifier() =>
      container.read(persistentWindowStateProvider(windowId).notifier);

  Map<String, dynamic> persistedData() {
    final raw =
        jsonDecode(
              File(
                '${directory.path}/persistent_window_abc.json',
              ).readAsStringSync(),
            )
            as Map;
    return (raw['data'] as Map).cast<String, dynamic>();
  }

  test('version 1 windows gain an empty resume context', () {
    final window = container.read(persistentWindowStateProvider(windowId));

    expect(window.resumeContext, isNull);
    expect(window.resumeTimedOut, isFalse);
    expect(window.properties.appId, 'foot');
    expect(window.properties.title, '~/src');
  });

  test('capture updates the context and persists it', () async {
    final info = ProcessInfoMessage(
      pid: 12,
      cgroup: '/launch/term',
      cmdline: const ['foot'],
      cwd: '/home/user',
      exe: '/usr/bin/foot',
      terminal: TerminalInfoMessage(
        shell: ProcessDescriptorMessage(
          pid: 13,
          cmdline: const ['fish'],
          cwd: '/home/user/src',
          exe: '/usr/bin/fish',
        ),
      ),
    );

    notifier().captureResumeContext(info);
    await flushPendingWrites();

    final window = container.read(persistentWindowStateProvider(windowId));
    expect(window.resumeContext?.workingDirectory, '/home/user/src');
    expect(window.resumeContext?.terminal?.shell, '/usr/bin/fish');
    expect(window.resumeContext?.cgroup, '/launch/term');

    final persisted = persistedData();
    expect(persisted['resumeContext'], isA<Map<String, dynamic>>());
  });

  test('capture does not rewrite an unchanged context', () async {
    final info = ProcessInfoMessage(
      pid: 12,
      cmdline: const ['foot'],
      cwd: '/home/user',
      exe: '/usr/bin/foot',
    );

    notifier().captureResumeContext(info);
    final first = container
        .read(persistentWindowStateProvider(windowId))
        .resumeContext!
        .capturedAt;

    await Future<void>.delayed(const Duration(milliseconds: 5));
    notifier().captureResumeContext(info);
    final second = container
        .read(persistentWindowStateProvider(windowId))
        .resumeContext!
        .capturedAt;

    // The same facts keep the original capture time, so polling an idle tile
    // does not churn the persisted state.
    expect(second, first);
  });

  test('forget clears only the context and title', () async {
    notifier().captureResumeContext(
      ProcessInfoMessage(
        pid: 12,
        cmdline: const ['foot'],
        cwd: '/home/user',
        exe: '/usr/bin/foot',
      ),
    );

    notifier().forgetResumeContext();
    await flushPendingWrites();

    final window = container.read(persistentWindowStateProvider(windowId));
    expect(window.resumeContext, isNull);
    expect(window.properties.title, isNull);
    expect(window.properties.appId, 'foot');
    expect(window.displayMode, DisplayMode.maximized);

    final persisted = persistedData();
    expect(persisted['resumeContext'], isNull);
    expect((persisted['properties'] as Map)['appId'], 'foot');
  });
}
