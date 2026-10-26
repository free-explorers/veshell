import 'dart:convert';
import 'dart:io';

import 'package:hooks_riverpod/experimental/persist.dart' as persist;
import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/model/persistence_schema.dart';
import 'package:shell/shared/util/file.dart';
import 'package:shell/shared/util/logger.dart';

part 'persistent_storage_state.g.dart';

/// Directory where the shell keeps its persisted state.
///
/// Resolved lazily from the compositor-provided configuration directory so
/// tests can load a storage from a temporary directory without touching the
/// real user state.
Directory resolvePersistenceDirectory({Map<String, String>? environment}) {
  final variables = environment ?? Platform.environment;
  final configDirectory = variables['VESHELL_CONFIG_DIR'];
  if (configDirectory == null || configDirectory.isEmpty) {
    throw StateError(
      'VESHELL_CONFIG_DIR is not set: cannot locate the persistence directory',
    );
  }
  return Directory('$configDirectory/persistence');
}

@Riverpod(keepAlive: true)
Directory persistenceDirectory(Ref ref) => resolvePersistenceDirectory();

@Riverpod(keepAlive: true)
class PersistentStorageState extends _$PersistentStorageState {
  @override
  Future<PersistentStorage> build() => PersistentStorage.load(
    directory: ref.watch(persistenceDirectoryProvider),
  );
}

final class PersistentStorage extends persist.Storage<String, String> {
  PersistentStorage._(this.initialStoredData, this.directory);

  /// JSON of every loaded key, after migration and without the envelope.
  final Map<String, String> initialStoredData;

  final Directory directory;

  static const _quarantineDirectoryName = 'quarantine';

  static Future<PersistentStorage> load({Directory? directory}) async {
    final root = directory ?? resolvePersistenceDirectory();
    await root.create(recursive: true);
    // The state contains window titles, working directories and document
    // paths. Keep the directory private to the user, including on an existing
    // installation that was created with the process umask.
    await setPathPermissions(root.path, '700');

    final storedData = <String, String>{};
    var loaded = 0;
    var migrated = 0;
    var quarantined = 0;

    // Snapshot the directory before rewriting migrated files: listing while
    // renaming temp files into place can otherwise surface transient entries.
    final entities = await root.list().toList();
    for (final entity in entities) {
      if (entity is! File) {
        continue;
      }
      if (entity.path.endsWith('.tmp')) {
        // A previous process died between writing the temp file and renaming
        // it. The real file is still the last complete write.
        try {
          await entity.delete();
        } on FileSystemException catch (error) {
          persistenceLog.warning(
            'Could not delete stale temp file ${entity.path}: $error',
          );
        }
        continue;
      }
      if (!entity.path.endsWith('.json')) {
        continue;
      }

      final key = path.basenameWithoutExtension(entity.path);
      final raw = await entity.readAsString();
      try {
        final decoded = decodePersistedJson(key, raw);
        storedData[key] = jsonEncode(decoded.data);
        loaded++;

        if (decoded.migrated) {
          migrated++;
          persistenceLog.info(
            'Migrated $key (${decoded.store.name}) from version '
            '${decoded.fromVersion} to '
            '${decoded.store.currentVersion}',
          );
          try {
            await writeFileAtomicallyNow(
              entity.path,
              encodePersistedJson(key, storedData[key]!),
            );
            await setPathPermissions(entity.path, '600');
          } on Object catch (error) {
            // The migrated data is valid and usable in memory; failing to
            // rewrite it only means the migration runs again next startup.
            persistenceLog.warning('Could not persist migrated $key: $error');
          }
        } else {
          await setPathPermissions(entity.path, '600');
        }
      } on PersistenceQuarantineException catch (error) {
        quarantined++;
        await _quarantine(entity, error.reason);
      } on Object catch (error, stackTrace) {
        quarantined++;
        await _quarantine(entity, 'failed to load: $error');
        persistenceLog.warning(
          'Unexpected load failure for $key',
          error,
          stackTrace,
        );
      }
    }

    final loadedKeys = storedData.keys.toList()..sort();
    persistenceLog.info(
      'Loaded $loaded persisted file(s) from ${root.path}'
      '${loadedKeys.isEmpty ? '' : ': ${loadedKeys.join(', ')}'}'
      ' (migrated $migrated, quarantined $quarantined)',
    );
    return PersistentStorage._(storedData, root);
  }

  static Future<void> _quarantine(File source, String reason) async {
    final key = path.basenameWithoutExtension(source.path);
    final quarantineDirectory = Directory(
      path.join(source.parent.path, _quarantineDirectoryName),
    );
    await quarantineDirectory.create(recursive: true);
    await setPathPermissions(quarantineDirectory.path, '700');

    final stamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    var target = File(path.join(quarantineDirectory.path, '$key.$stamp.json'));
    var suffix = 0;
    while (target.existsSync()) {
      suffix++;
      target = File(
        path.join(quarantineDirectory.path, '$key.$stamp-$suffix.json'),
      );
    }

    try {
      await source.rename(target.path);
      await setPathPermissions(target.path, '600');
      persistenceLog.severe('Quarantined $key to ${target.path}: $reason');
    } on FileSystemException catch (error) {
      // Do not delete a file we could not move: leaving it in place is safer
      // than silently starting from an empty state with no recovery path.
      persistenceLog.severe('Could not quarantine $key ($reason): $error');
    }
  }

  @override
  Future<void> delete(String key) async {
    final file = File(path.join(directory.path, '$key.json'));
    initialStoredData.remove(key);
    await deleteFileQueued(file.path);
  }

  @override
  persist.PersistedData<String>? read(String key) {
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
    await writeFileAtomically(
      path.join(directory.path, '$key.json'),
      encodePersistedJson(key, value),
    );
  }

  @override
  void deleteOutOfDate() {
    // Every store uses `StorageCacheTime.unsafe_forever`; expiration is not
    // part of the on-disk format.
  }
}
