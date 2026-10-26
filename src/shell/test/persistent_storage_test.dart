import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/experimental/persist.dart';
import 'package:shell/shared/model/persistence_schema.dart';
import 'package:shell/shared/provider/persistent_storage_state.dart';
import 'package:shell/shared/util/file.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('veshell_storage_');
  });

  tearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  File stateFile(String key) => File('${directory.path}/$key.json');

  int modeOf(String path) => FileStat.statSync(path).mode & 0x1FF;

  test('creates the persistence directory owner-only', () async {
    await Process.run('chmod', ['755', directory.path]);

    await PersistentStorage.load(directory: directory);

    // chmod(1) permission bits for 0700.
    expect(modeOf(directory.path), 0x1C0);
  });

  test('migrates a legacy file and rewrites it with the envelope', () async {
    final file = stateFile('persistent_window_abc');
    await file.writeAsString(
      jsonEncode({
        'windowId': 'abc',
        'properties': {'appId': 'firefox', 'title': 'Mozilla'},
      }),
    );
    await Process.run('chmod', ['644', file.path]);

    final storage = await PersistentStorage.load(directory: directory);
    final stored = storage.read('persistent_window_abc');

    expect(stored, isNotNull);
    expect(jsonDecode(stored!.data), {
      'windowId': 'abc',
      'properties': {'appId': 'firefox', 'title': 'Mozilla'},
      'resumeContext': null,
      'resumeTimedOut': false,
    });

    // The legacy content is rewritten with the envelope, and the file is
    // narrowed while doing so.
    final rewritten = jsonDecode(await file.readAsString());
    expect(
      (rewritten as Map)[persistenceEnvelopeKey],
      isA<Map<dynamic, dynamic>>(),
    );
    expect(rewritten['data'], {
      'windowId': 'abc',
      'properties': {'appId': 'firefox', 'title': 'Mozilla'},
      'resumeContext': null,
      'resumeTimedOut': false,
    });
    expect(modeOf(file.path), 0x180); // 0600
  });

  test('narrows an existing unversioned file on load', () async {
    final file = stateFile('workspace_abc');
    await file.writeAsString(jsonEncode({'workspaceId': 'abc'}));
    await Process.run('chmod', ['666', file.path]);

    await PersistentStorage.load(directory: directory);

    expect(modeOf(file.path), 0x180);
  });

  test('quarantines a file written by a newer shell', () async {
    final file = stateFile('persistent_window_abc');
    final raw = jsonEncode({
      persistenceEnvelopeKey: {
        'store': PersistenceStore.persistentWindow.name,
        'version': PersistenceStore.persistentWindow.currentVersion + 1,
      },
      'data': {'windowId': 'abc'},
    });
    await file.writeAsString(raw);

    final storage = await PersistentStorage.load(directory: directory);

    expect(storage.read('persistent_window_abc'), isNull);
    expect(file.existsSync(), isFalse);

    final quarantine = Directory('${directory.path}/quarantine');
    expect(quarantine.existsSync(), isTrue);
    final files = quarantine.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    expect(await files.single.readAsString(), raw);
    expect(modeOf(files.single.path), 0x180);
  });

  test('quarantines malformed JSON instead of dropping it', () async {
    final file = stateFile('workspace_abc');
    await file.writeAsString('{not json');

    final storage = await PersistentStorage.load(directory: directory);

    expect(storage.read('workspace_abc'), isNull);
    expect(file.existsSync(), isFalse);
    expect(
      Directory('${directory.path}/quarantine').listSync().whereType<File>(),
      hasLength(1),
    );
  });

  test('deletes stale temp files left by an unclean exit', () async {
    final temp = File('${directory.path}/workspace_abc.json.tmp');
    await temp.writeAsString('partial');

    await PersistentStorage.load(directory: directory);

    expect(temp.existsSync(), isFalse);
  });

  test('writes the current envelope and flushes to disk', () async {
    final storage = await PersistentStorage.load(directory: directory);

    await storage.write(
      'screen_manager',
      jsonEncode({'screenIds': <String>[]}),
      const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );
    await flushPendingWrites();

    final file = stateFile('screen_manager');
    expect(file.existsSync(), isTrue);
    expect(modeOf(file.path), 0x180);

    final decoded = jsonDecode(await file.readAsString()) as Map;
    final envelope = decoded[persistenceEnvelopeKey] as Map<String, dynamic>;
    expect(envelope['store'], PersistenceStore.screen.name);
    expect(envelope['version'], PersistenceStore.screen.currentVersion);
    expect(decoded['data'], {'screenIds': <String>[]});
  });

  test('delete cancels a pending write for the same key', () async {
    final storage = await PersistentStorage.load(directory: directory);

    await storage.write(
      'workspace_abc',
      jsonEncode({'workspaceId': 'abc'}),
      const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
    );
    await storage.delete('workspace_abc');
    await flushPendingWrites();

    expect(stateFile('workspace_abc').existsSync(), isFalse);
    expect(storage.read('workspace_abc'), isNull);
  });
}
