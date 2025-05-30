import 'dart:io';

import 'package:hooks_riverpod/experimental/persist.dart' as persist;
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/util/file.dart';

part 'persistent_storage_state.g.dart';

Directory persistenceDirectory = Directory(
  '${Platform.environment['VESHELL_CONFIG_DIR']!}/persistence',
);

@Riverpod(keepAlive: true)
class PersistentStorageState extends _$PersistentStorageState {
  @override
  Future<PersistentStorage> build() async {
    await persistenceDirectory.create(recursive: true);
    return PersistentStorage.load();
  }
}

class PersistentStorage implements persist.Storage<String, String> {
  PersistentStorage._(this.initialStoredData);
  final Map<String, String> initialStoredData;

  static Future<PersistentStorage> load() async {
    final persistentFolder = Directory(path.join(persistenceDirectory.path));
    final storedData = <String, String>{};
    if (persistentFolder.existsSync()) {
      await for (final file in persistentFolder.list()) {
        if (file is File) {
          //remove tmp files
          if (file.path.endsWith('.tmp')) {
            await file.delete();
            continue;
          }
          final fileName = path.basenameWithoutExtension(file.path);
          storedData[fileName] = await file.readAsString();
        }
      }
    }
    return PersistentStorage._(storedData);
  }

  @override
  Future<void> delete(String key) async {
    print('delete $key');
    final file = File(path.join(persistenceDirectory.path, '$key.json'));
    if (file.existsSync()) {
      await file.delete();
    }
  }

  @override
  persist.PersistedData<String>? read(String key) {
    print('Storage read $key');
    final data = initialStoredData[key];
    if (data == null) {
      return null;
    }
    return persist.PersistedData(data);
  }

  @override
  Future<void> write(
    String key,
    String value,
    persist.StorageOptions options,
  ) async {
    print('Storage write $key');
    await writeFileAtomically(
      path.join(persistenceDirectory.path, '$key.json'),
      value,
    );
  }
}
