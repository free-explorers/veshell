import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/shared/util/file.dart';
import 'package:shell/systemd/provider/session_guard.dart';

void main() {
  late Directory directory;
  late String path;
  late StreamController<bool> signals;
  late ProviderContainer container;
  ProviderSubscription<void>? guardSubscription;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('veshell_session_guard_');
    path = '${directory.path}/state.json';
    signals = StreamController<bool>();
    container = ProviderContainer(
      overrides: [
        prepareForShutdownSignalsProvider.overrideWith((ref) => signals.stream),
      ],
    );
    guardSubscription = null;
    addTearDown(container.dispose);
  });

  tearDown(() async {
    guardSubscription?.close();
    await signals.close();
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  SessionGuard guard() {
    // Keep the guard provider listened to: an unwatched provider is paused in
    // Riverpod 3, which would also pause its stream dependency.
    guardSubscription ??= container.listen(sessionGuardProvider, (_, _) {});
    return container.read(sessionGuardProvider.notifier);
  }

  test(
    'PrepareForShutdown latches the guard and flushes pending state',
    () async {
      final sessionGuard = guard();
      await writeFileAtomically(path, 'last-context');

      signals.add(true);
      await pumpEventQueue();

      expect(sessionGuard.isLeaving, isTrue);
      await flushPendingWrites();
      expect(File(path).readAsStringSync(), 'last-context');
    },
  );

  test('a cancelled shutdown clears the guard', () async {
    final sessionGuard = guard();
    // Let the stream subscription start before emitting: a broadcast stream
    // drops events that have no listener yet.
    await pumpEventQueue();

    signals.add(true);
    await pumpEventQueue();
    expect(sessionGuard.isLeaving, isTrue);

    signals.add(false);
    await pumpEventQueue();
    expect(sessionGuard.isLeaving, isFalse);
  });

  test('beginLeaving sets the flag before awaiting the flush', () async {
    final sessionGuard = guard();
    await writeFileAtomically(path, 'pending');

    final future = sessionGuard.beginLeaving();
    // Teardown events can arrive while the flush is running: the flag must
    // already be visible.
    expect(sessionGuard.isLeaving, isTrue);
    await future;

    expect(File(path).readAsStringSync(), 'pending');
  });

  test('flushBeforeSuspend does not latch the teardown guard', () async {
    final sessionGuard = guard();
    await writeFileAtomically(path, 'pending');

    await sessionGuard.flushBeforeSuspend();

    expect(sessionGuard.isLeaving, isFalse);
    expect(File(path).readAsStringSync(), 'pending');
  });
}
