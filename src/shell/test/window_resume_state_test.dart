import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freedesktop_desktop_entry/freedesktop_desktop_entry.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/model/launch_config.serializable.dart';
import 'package:shell/application/model/launch_handle.dart';
import 'package:shell/application/model/launch_scope_tracker.dart';
import 'package:shell/application/provider/app_launch.dart';
import 'package:shell/application/provider/localized_desktop_entries.dart';
import 'package:shell/platform/model/event/process_info/process_info.serializable.dart';
import 'package:shell/shared/model/persistence_schema.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/shared/util/file.dart';
import 'package:shell/systemd/provider/session_guard.dart';
import 'package:shell/window/model/persistent_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/provider/persistent_window_state.dart';

/// A launched process whose exit the test decides.
class _FakeProcess implements Process {
  _FakeProcess(this.pid);

  @override
  final int pid;

  final _exit = Completer<int>();

  void exit(int code) => _exit.complete(code);

  @override
  Future<int> get exitCode => _exit.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Hands out [_FakeProcess]es instead of starting anything.
/// Hands out launches of [_FakeProcess]es instead of starting anything.
///
/// The handles are real: with a [slice], they follow the application's unit
/// in it through inotify, as [AppLaunch.launch] does in `app.slice`.
class _FakeAppLaunch extends AppLaunch {
  _FakeAppLaunch({required this.slice});

  final launched = <_FakeProcess>[];

  /// What each launch was carried out by, in order (null for the tile itself).
  final carriers = <Set<String>?>[];

  /// Stands in for `app.slice`, for the tests that follow a unit.
  final Directory? Function() slice;

  @override
  Future<LaunchHandle> launch(
    LaunchConfig config, {
    required WindowId forWindowId,
    ScopeIdentity? scope,
    Set<String>? carriedOutBy,
  }) async {
    final process = _FakeProcess(1000 + launched.length);
    launched.add(process);
    carriers.add(carriedOutBy);
    return LaunchHandle(
      process: process,
      handsOff: carriedOutBy != null,
      followUnit: followUnitIn(slice(), scope),
    );
  }

  @override
  void cancelPendingLaunch(WindowId windowId) {}
}

/// No desktop entry: the tile resumes from its saved context alone.
class _NoDesktopEntry extends LocalizedDesktopEntryForId {
  @override
  Future<LocalizedDesktopEntry?> build(String appId) async => null;
}

/// Waits until [condition] holds, for events delivered by inotify.
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not reached in time');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  const windowId = PersistentWindowId('abc');
  late _FakeAppLaunch appLaunch;
  Directory? appSlice;

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

    appLaunch = _FakeAppLaunch(slice: () => appSlice);
    container = ProviderContainer(
      overrides: [
        appLaunchProvider.overrideWith(() => appLaunch),
        localizedDesktopEntryForIdProvider.overrideWith2(
          (_) => _NoDesktopEntry(),
        ),
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

  group('a resumed launch', () {
    Future<_FakeProcess> launch() async {
      // A custom exec spares the desktop-entry lookup.
      notifier().setCustomExec('steam steam://rungameid/570');
      await notifier().launchSelf();
      return appLaunch.launched.last;
    }

    PersistentWindow window() =>
        container.read(persistentWindowStateProvider(windowId));

    test('keeps waiting for its window after a clean hand-off', () async {
      final process = await launch();
      expect(window().isWaitingForSurface, isTrue);

      process.exit(0);
      await pumpEventQueue();

      expect(window().isWaitingForSurface, isTrue);
      expect(window().resumeTimedOut, isFalse);
    });

    test('stops waiting when the launcher fails', () async {
      final process = await launch();

      process.exit(1);
      await pumpEventQueue();

      expect(window().isWaitingForSurface, isFalse);
    });

    test('ignores the exit of a launch a retry replaced', () async {
      final first = await launch();
      await notifier().retryResume();
      expect(appLaunch.launched, hasLength(2));

      first.exit(1);
      await pumpEventQueue();

      expect(window().isWaitingForSurface, isTrue);
      expect(window().pid, appLaunch.launched.last.pid);
    });
  });

  group('a Steam game handed off to Steam', () {
    late Directory slice;

    setUp(() {
      slice = Directory.systemTemp.createTempSync('veshell_app_slice_');
      appSlice = slice;
      PersistentWindowState.scopeEndGrace = Duration.zero;
    });

    tearDown(() {
      PersistentWindowState.scopeEndGrace = const Duration(seconds: 5);
      appSlice = null;
      slice.deleteSync(recursive: true);
    });

    PersistentWindow window() =>
        container.read(persistentWindowStateProvider(windowId));

    Future<_FakeProcess> launchGame() async {
      notifier().captureResumeContext(
        ProcessInfoMessage(
          pid: 42,
          cmdline: const [r'Z:\Game.exe'],
          exe: '/opt/Proton/files/bin/wine64-preloader',
          wine: WineInfoMessage(
            steamAppId: '570',
            compatDataPath: '/steam/compatdata/570',
          ),
        ),
      );
      await notifier().launchSelf();
      final forwarder = appLaunch.launched.last;
      // Let the directory watch start before Steam creates the scope.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      forwarder.exit(0);
      await pumpEventQueue();
      return forwarder;
    }

    test('shows at once a game that quit before any window', () async {
      await launchGame();
      final scope = Directory('${slice.path}/app-steam-app570-4242.scope')
        ..createSync();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(window().isWaitingForSurface, isTrue);

      scope.deleteSync();
      await _until(() => window().resumeTimedOut);

      expect(window().isWaitingForSurface, isFalse);
    });

    test('is launched as Steam, not as the game tile', () async {
      await launchGame();

      expect(appLaunch.carriers.single, contains('steam'));
    });

    test('ignores the scope of another game', () async {
      await launchGame();
      final other = Directory('${slice.path}/app-steam-app440-1.scope')
        ..createSync();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      other.deleteSync();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(window().isWaitingForSurface, isTrue);
      expect(window().resumeTimedOut, isFalse);
    });
  });
}
