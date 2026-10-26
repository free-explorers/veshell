import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shell/shared/model/persistence_schema.dart';

void main() {
  group('persistenceStoreForKey', () {
    test('maps every persisted state family to its store', () {
      expect(
        persistenceStoreForKey('persistent_window_abc'),
        PersistenceStore.persistentWindow,
      );
      expect(
        persistenceStoreForKey('workspace_abc'),
        PersistenceStore.workspace,
      );
      expect(persistenceStoreForKey('screen_abc'), PersistenceStore.screen);
      expect(persistenceStoreForKey('screen_manager'), PersistenceStore.screen);
      expect(
        persistenceStoreForKey('monitor_configuration_DP-1'),
        PersistenceStore.monitor,
      );
      expect(
        persistenceStoreForKey('MonitorConfigurationState(DP-1)'),
        PersistenceStore.monitor,
      );
      expect(
        persistenceStoreForKey('monitor_manager'),
        PersistenceStore.monitor,
      );
      expect(
        persistenceStoreForKey('MonitorManager'),
        PersistenceStore.monitor,
      );
      expect(
        persistenceStoreForKey('window_manager'),
        PersistenceStore.windowManager,
      );
      expect(
        persistenceStoreForKey('WindowManager'),
        PersistenceStore.windowManager,
      );
      expect(
        persistenceStoreForKey('notification_something'),
        PersistenceStore.notification,
      );
      expect(
        persistenceStoreForKey('NotificationManager'),
        PersistenceStore.notification,
      );
      expect(persistenceStoreForKey('unknown'), PersistenceStore.other);
    });
  });

  group('decodePersistedJson', () {
    test('migrates a legacy unversioned file', () {
      final decoded = decodePersistedJson(
        'persistent_window_abc',
        jsonEncode({
          'windowId': 'abc',
          'properties': {'appId': 'firefox', 'title': 'Mozilla'},
        }),
      );

      expect(decoded.store, PersistenceStore.persistentWindow);
      expect(decoded.fromVersion, 0);
      expect(decoded.migrated, isTrue);
      expect(decoded.data['windowId'], 'abc');
      expect(decoded.data['properties'], {
        'appId': 'firefox',
        'title': 'Mozilla',
      });
    });

    test('loads a current envelope without migrating', () {
      final encoded = encodePersistedJson(
        'workspace_abc',
        jsonEncode({'workspaceId': 'abc'}),
      );
      final decoded = decodePersistedJson('workspace_abc', encoded);

      expect(decoded.store, PersistenceStore.workspace);
      expect(decoded.fromVersion, PersistenceStore.workspace.currentVersion);
      expect(decoded.migrated, isFalse);
      expect(decoded.data['workspaceId'], 'abc');
    });

    test('quarantines a file written by a newer shell', () {
      final raw = jsonEncode({
        persistenceEnvelopeKey: {
          'store': PersistenceStore.persistentWindow.name,
          'version': PersistenceStore.persistentWindow.currentVersion + 1,
        },
        'data': {'windowId': 'abc'},
      });

      expect(
        () => decodePersistedJson('persistent_window_abc', raw),
        throwsA(isA<PersistenceQuarantineException>()),
      );
    });

    test('quarantines an unknown store', () {
      final raw = jsonEncode({
        persistenceEnvelopeKey: {'store': 'future_store', 'version': 1},
        'data': {'x': 1},
      });

      expect(
        () => decodePersistedJson('persistent_window_abc', raw),
        throwsA(isA<PersistenceQuarantineException>()),
      );
    });

    test('quarantines malformed JSON', () {
      expect(
        () => decodePersistedJson('persistent_window_abc', '{not json'),
        throwsA(isA<PersistenceQuarantineException>()),
      );
    });

    test('quarantines a non-object payload', () {
      expect(
        () => decodePersistedJson('persistent_window_abc', '[]'),
        throwsA(isA<PersistenceQuarantineException>()),
      );
      expect(
        () => decodePersistedJson(
          'persistent_window_abc',
          jsonEncode({
            persistenceEnvelopeKey: {
              'store': PersistenceStore.persistentWindow.name,
              'version': 1,
            },
            'data': 42,
          }),
        ),
        throwsA(isA<PersistenceQuarantineException>()),
      );
    });

    test('quarantines a missing migration step', () {
      final raw = jsonEncode({
        persistenceEnvelopeKey: {
          'store': PersistenceStore.persistentWindow.name,
          // A store version this build understands but whose migration chain
          // is incomplete is treated as unreadable rather than guessed.
          'version': -1,
        },
        'data': {'windowId': 'abc'},
      });

      expect(
        () => decodePersistedJson('persistent_window_abc', raw),
        throwsA(isA<PersistenceQuarantineException>()),
      );
    });
  });

  group('encodePersistedJson', () {
    test('writes the envelope and keeps the model data intact', () {
      final encoded = encodePersistedJson(
        'persistent_window_abc',
        jsonEncode({'windowId': 'abc'}),
      );
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final envelope = decoded[persistenceEnvelopeKey] as Map<String, dynamic>;

      expect(envelope['store'], PersistenceStore.persistentWindow.name);
      expect(
        envelope['version'],
        PersistenceStore.persistentWindow.currentVersion,
      );
      expect(decoded['data'], {'windowId': 'abc'});
    });
  });
}
