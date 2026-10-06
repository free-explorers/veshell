import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/model/system_locale.dart';
import 'package:shell/shared/provider/dbus_client.dart';

part 'system_locale.g.dart';

/// Injectable boundary: tests never call the real privileged system service.
abstract class SystemLocaleService {
  Stream<void> get changes;
  Future<Map<String, String>> read();
  Future<void> write(Map<String, String> assignments);
}

class Locale1Service implements SystemLocaleService {
  Locale1Service(DBusClient client)
    : _object = DBusRemoteObject(
        client,
        name: 'org.freedesktop.locale1',
        path: DBusObjectPath('/org/freedesktop/locale1'),
      );

  static const _interface = 'org.freedesktop.locale1';
  final DBusRemoteObject _object;

  @override
  Stream<void> get changes => _object.propertiesChanged
      .where(
        (event) =>
            event.propertiesInterface == _interface &&
            (event.changedProperties.containsKey('Locale') ||
                event.invalidatedProperties.contains('Locale')),
      )
      .map((_) {});

  @override
  Future<Map<String, String>> read() async {
    final value = await _object.getProperty(_interface, 'Locale');
    return parseSystemLocaleAssignments(value.asStringArray());
  }

  @override
  Future<void> write(Map<String, String> assignments) async {
    final keys = assignments.keys.toList()..sort();
    await _object.callMethod(
      _interface,
      'SetLocale',
      [
        DBusArray.string(keys.map((key) => '$key=${assignments[key]}')),
        const DBusBoolean(true),
      ],
      replySignature: DBusSignature(''),
      allowInteractiveAuthorization: true,
    );
  }
}

@riverpod
SystemLocaleService systemLocaleService(Ref ref) =>
    Locale1Service(ref.watch(dbusClientProvider));

@riverpod
Future<List<String>> installedSystemLocales(Ref ref) async {
  final result = await Process.run(
    'locale',
    ['-a'],
    environment: {'LC_ALL': 'C'},
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      'locale',
      ['-a'],
      '${result.stderr}',
      result.exitCode,
    );
  }
  return parseInstalledSystemLocales('${result.stdout}');
}

@riverpod
class SystemLocale extends _$SystemLocale {
  @override
  Future<Map<String, String>> build() async {
    final service = ref.watch(systemLocaleServiceProvider);
    final subscription = service.changes.listen(
      (_) => ref.invalidateSelf(),
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncError(error, stackTrace);
      },
    );
    ref.onDispose(subscription.cancel);
    final configuration = await service.read();
    if (ref.mounted) {
      ref
          .read(configuredSystemLocalesProvider.notifier)
          .update(systemMessageLocales(configuration));
    }
    return configuration;
  }

  Future<Map<String, String>> apply({
    required Map<String, String> expected,
    required Map<String, String?> changes,
  }) async {
    final service = ref.read(systemLocaleServiceProvider);
    final installed = await ref.read(installedSystemLocalesProvider.future);
    final current = await service.read();
    if (!mapEquals(current, expected)) {
      throw SystemLocaleConflict();
    }
    final next = applySystemLocaleChanges(current, changes, installed);
    if (!mapEquals(current, next)) {
      await service.write(next);
    }
    if (ref.mounted) {
      ref
          .read(configuredSystemLocalesProvider.notifier)
          .update(systemMessageLocales(next));
      ref.invalidateSelf();
    }
    return next;
  }
}
