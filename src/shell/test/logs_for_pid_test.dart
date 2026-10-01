import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/application/provider/logs_for_pid.dart';

void main() {
  // Regression: the captured output was appended forever for a keep-alive
  // process, so a chatty application grew the shell's heap as long as it ran.
  test('captured output is trimmed once it exceeds the cap', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const pid = 0x5eed;
    final notifier = container.read(logsForPidProvider(pid).notifier);
    final process = await Process.start('sh', [
      '-c',
      r'head -c 400000 /dev/zero | tr "\0" a',
    ]);
    notifier.setProcess(process, command: 'chatty');
    await process.exitCode;
    await pumpEventQueue();

    final state = container.read(logsForPidProvider(pid));
    final total = state.lines.fold<int>(0, (sum, line) => sum + line.length);
    expect(total, greaterThan(0));
    expect(total, lessThanOrEqualTo(maxLogCharacters * 2));
    expect(state.isRunning, isFalse);
  });
}
