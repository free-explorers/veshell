import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shell/shared/util/file.dart';

void main() {
  late Directory directory;
  late String path;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('veshell_write_file_');
    path = '${directory.path}/state.json';
  });

  tearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  test('coalesces rapid writes and keeps the last content', () async {
    for (var i = 0; i < 25; i++) {
      await writeFileAtomically(path, 'value-$i');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(File(path).readAsStringSync(), 'value-24');
    // The temp file is renamed away, never left next to the real one.
    expect(File('$path.tmp').existsSync(), isFalse);
  });

  test('serializes overlapping flushes without unhandled errors', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      // Fire writes across several debounce windows so the per-path chain has
      // to queue them, and never await: a shared temp file would race here.
      for (var i = 0; i < 40; i++) {
        unawaited(writeFileAtomically(path, 'burst-$i'));
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }, (error, stackTrace) => errors.add(error));

    expect(errors, isEmpty);
    expect(File(path).readAsStringSync(), 'burst-39');
    expect(File('$path.tmp').existsSync(), isFalse);
  });
}
