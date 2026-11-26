import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shell/application/model/launch_handle.dart';
import 'package:shell/application/model/launch_scope_tracker.dart';

/// A launch process whose exit the test decides.
class _FakeProcess implements Process {
  final _exit = Completer<int>();

  void exit(int code) => _exit.complete(code);

  @override
  int get pid => 4242;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const slice = '/sys/fs/cgroup/user.slice/user-1000.slice/app.slice';
  const scope = 'app-steam-app570-4242.scope';

  late _FakeProcess process;
  late StreamController<FileSystemEvent> sliceEvents;

  setUp(() {
    process = _FakeProcess();
    sliceEvents = StreamController<FileSystemEvent>();
  });

  tearDown(() => sliceEvents.close());

  LaunchHandle launch() => LaunchHandle(
    process: process,
    carriedOutBy: const {'steam'},
    followUnit: (onStarted, onEnded) => LaunchScopeTracker(
      slicePath: slice,
      identity: const ScopeIdentity.steamGame('570'),
      onStarted: onStarted,
      onEnded: onEnded,
      watch: (_) => sliceEvents.stream,
      list: (_) => const [],
    ),
  );

  String describe(LaunchEvent event) => switch (event) {
    LaunchExited(:final exitCode) => 'exited $exitCode',
    LaunchUnitStarted(:final unit) => 'started $unit',
    LaunchUnitEnded(:final unit) => 'ended $unit',
  };

  test('reports a hand-off, then the unit the application ran in', () async {
    final handle = launch();
    final events = <String>[];
    handle.events.map(describe).listen(events.add);

    process.exit(0);
    await pumpEventQueue();
    expect(handle.unitStarted, isFalse);
    sliceEvents.add(FileSystemCreateEvent('$slice/$scope', true));
    await pumpEventQueue();
    expect(handle.unitStarted, isTrue);
    sliceEvents.add(FileSystemDeleteEvent('$slice/$scope', true));
    await pumpEventQueue();

    expect(events, ['exited 0', 'started $scope', 'ended $scope']);
  });

  test('keeps what happened before anyone listened', () async {
    final handle = launch();
    sliceEvents.add(FileSystemCreateEvent('$slice/$scope', true));
    process.exit(0);
    await pumpEventQueue();

    expect(await handle.events.map(describe).take(2).toList(), [
      'started $scope',
      'exited 0',
    ]);
  });

  test('stops following the unit once the launch failed', () async {
    final handle = launch();
    final events = <String>[];
    handle.events.map(describe).listen(events.add);

    process.exit(1);
    await pumpEventQueue();
    sliceEvents.add(FileSystemCreateEvent('$slice/$scope', true));
    await pumpEventQueue();

    expect(events, ['exited 1']);
  });

  test('reports nothing once cancelled', () async {
    final handle = launch();
    final events = <String>[];
    handle.events
        .map(describe)
        .listen(
          events.add,
          onDone: () {
            events.add('done');
          },
        );

    handle.cancel();
    sliceEvents.add(FileSystemCreateEvent('$slice/$scope', true));
    process.exit(0);
    await pumpEventQueue();

    expect(events, ['done']);
  });
}
