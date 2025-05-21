import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/config_directory.dart';

part 'configured_settings_json.g.dart';

@riverpod
class ConfiguredSettingsJson extends _$ConfiguredSettingsJson {
  StreamSubscription<FileSystemEvent>? _subscription;
  @override
  Map<String, dynamic> build() {
    final configDirectory = ref.watch(configDirectoryProvider);
    final configuredSettingsFile =
        File('${configDirectory.path}/settings.json');

    _subscription?.cancel();

    if (!configuredSettingsFile.existsSync()) {
      _subscription =
          configDirectory.watch(events: FileSystemEvent.move).listen((event) {
        if (event is FileSystemMoveEvent) {
          if (event.destination == configuredSettingsFile.path) {
            ref.invalidateSelf();
          }
        }
      });
      return {};
    }
    _subscription = configuredSettingsFile.watch().listen((event) {
      ref.invalidateSelf();
    });

    try {
      return jsonDecode(
        configuredSettingsFile.readAsStringSync(),
      ) as Map<String, dynamic>;
    } on Exception catch (_) {
      return {};
    }
  }
}
