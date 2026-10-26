import 'dart:convert';

import 'package:collection/collection.dart';

/// The key carrying the persistence envelope around a model's JSON.
///
/// Previous releases wrote the model JSON directly. Those files are read as
/// version 0 and migrated to the current version the first time they are
/// loaded, so adding the envelope does not drop existing state.
const persistenceEnvelopeKey = r'$veshell';

/// A family of persisted files that share a schema and a migration chain.
enum PersistenceStore {
  persistentWindow,
  workspace,
  screen,
  monitor,
  windowManager,
  notification,
  other,
}

extension PersistenceStoreSchema on PersistenceStore {
  /// The version written by this build.
  ///
  /// Bump this and add the matching `version -> version + 1` migration in
  /// [_persistenceMigrations] whenever a persisted model changes shape.
  int get currentVersion => switch (this) {
    // Version 1 is the first versioned on-disk layout (the envelope).
    // Version 2 adds the per-tile resume context and its runtime timeout flag.
    PersistenceStore.persistentWindow => 2,
    _ => 1,
  };
}

/// Resolves the store owning [key].
///
/// Keys are the stable names chosen by the state providers:
/// `persistent_window_<uuid>`, `workspace_<id>`, `screen_<id>`,
/// `ScreenManager`, `MonitorManager`, `MonitorConfigurationState(<id>)`,
/// `WindowManager` and `NotificationManager`.
PersistenceStore persistenceStoreForKey(String key) {
  if (key == 'WindowManager' || key == 'window_manager') {
    return PersistenceStore.windowManager;
  }
  if (key.startsWith('persistent_window_')) {
    return PersistenceStore.persistentWindow;
  }
  if (key.startsWith('workspace_')) {
    return PersistenceStore.workspace;
  }
  if (key == 'ScreenManager' ||
      key == 'screen_manager' ||
      key.startsWith('screen_')) {
    return PersistenceStore.screen;
  }
  if (key == 'MonitorManager' ||
      key == 'monitor_manager' ||
      key.startsWith('MonitorConfigurationState') ||
      key.startsWith('monitor_configuration_')) {
    return PersistenceStore.monitor;
  }
  if (key == 'NotificationManager' || key.startsWith('notification')) {
    return PersistenceStore.notification;
  }
  return PersistenceStore.other;
}

/// A decoded, migrated persisted value.
class PersistedJson {
  const PersistedJson({
    required this.store,
    required this.data,
    required this.fromVersion,
    required this.migrated,
  });

  final PersistenceStore store;

  /// The model JSON, ready for the provider's `fromJson`.
  final Map<String, dynamic> data;

  /// The version the file was written with (0 for a pre-envelope file).
  final int fromVersion;

  /// Whether the value was upgraded and should be written back.
  final bool migrated;
}

/// Why a persisted file cannot be loaded and must be quarantined.
class PersistenceQuarantineException implements Exception {
  const PersistenceQuarantineException(this.reason);

  final String reason;

  @override
  String toString() => 'PersistenceQuarantineException: $reason';
}

/// Wraps a model's JSON in the current envelope for [key].
String encodePersistedJson(String key, String modelJson) {
  final Object? decoded;
  try {
    decoded = jsonDecode(modelJson);
  } on FormatException catch (error) {
    throw PersistenceQuarantineException(
      'cannot encode invalid JSON for $key: ${error.message}',
    );
  }
  if (decoded is! Map) {
    throw PersistenceQuarantineException(
      'cannot encode non-object JSON for $key (${decoded.runtimeType})',
    );
  }

  final store = persistenceStoreForKey(key);
  return jsonEncode({
    persistenceEnvelopeKey: {
      'store': store.name,
      'version': store.currentVersion,
    },
    'data': decoded,
  });
}

/// Decodes and migrates the raw contents of a persisted file.
///
/// Throws [PersistenceQuarantineException] for malformed JSON, an unknown
/// store, or a version newer than this build understands. The storage layer
/// moves the file aside instead of deleting it.
PersistedJson decodePersistedJson(String key, String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (error) {
    throw PersistenceQuarantineException(
      'invalid JSON for $key: ${error.message}',
    );
  }
  if (decoded is! Map) {
    throw PersistenceQuarantineException(
      'non-object JSON for $key (${decoded.runtimeType})',
    );
  }

  final map = decoded.cast<String, dynamic>();
  final envelope = map[persistenceEnvelopeKey];

  final PersistenceStore store;
  var version = 0;
  Map<String, dynamic> data;

  if (envelope == null) {
    // Legacy, unversioned file written before the envelope existed.
    store = persistenceStoreForKey(key);
    data = map;
  } else {
    if (envelope is! Map) {
      throw PersistenceQuarantineException(
        'invalid envelope for $key (${envelope.runtimeType})',
      );
    }
    final envelopeMap = envelope.cast<String, dynamic>();
    final storeName = envelopeMap['store'];
    final storeVersion = envelopeMap['version'];
    if (storeName is! String || storeVersion is! int) {
      throw PersistenceQuarantineException(
        'invalid envelope metadata for $key',
      );
    }
    store =
        PersistenceStore.values
            .where((candidate) => candidate.name == storeName)
            .firstOrNull ??
        (throw PersistenceQuarantineException(
          'unknown persistence store "$storeName" for $key',
        ));
    final rawData = map['data'];
    if (rawData is! Map) {
      throw PersistenceQuarantineException(
        'invalid envelope data for $key (${rawData.runtimeType})',
      );
    }
    version = storeVersion;
    data = rawData.cast<String, dynamic>();
  }

  if (version > store.currentVersion) {
    throw PersistenceQuarantineException(
      '$key was written by a newer shell: version $version > '
      '${store.currentVersion} (${store.name})',
    );
  }

  final fromVersion = version;
  while (version < store.currentVersion) {
    final migration = _persistenceMigrations[store]?[version];
    if (migration == null) {
      throw PersistenceQuarantineException(
        'no migration from version $version to ${version + 1} '
        'for ${store.name} ($key)',
      );
    }
    data = migration(data);
    version++;
  }

  return PersistedJson(
    store: store,
    data: data,
    fromVersion: fromVersion,
    migrated: fromVersion != version,
  );
}

typedef PersistenceMigration =
    Map<String, dynamic> Function(Map<String, dynamic> data);

/// Migrations keyed by store, then by the version they upgrade *from*.
///
/// A missing entry is not a no-op: it quarantines the file, so a version bump
/// can never silently load data the migration did not account for.
final Map<PersistenceStore, Map<int, PersistenceMigration>>
_persistenceMigrations = {
  for (final store in PersistenceStore.values)
    store: {
      // Version 0 is the pre-envelope layout. The old models already match
      // the current shape for every store, so the first migration only marks
      // the data as versioned.
      0: (data) => data,
      if (store == PersistenceStore.persistentWindow)
        1: _persistentWindowV1ToV2,
    },
};

/// Adds the resume-context fields to a pre-resume tile.
///
/// Persisted windows are migrated before the freezed decoder runs, so a field
/// added here is never silently discarded because the decoder threw first.
Map<String, dynamic> _persistentWindowV1ToV2(Map<String, dynamic> data) => {
  ...data,
  'resumeContext': data['resumeContext'],
  'resumeTimedOut': data['resumeTimedOut'] ?? false,
};
