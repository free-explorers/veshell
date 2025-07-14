import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/config_directory.dart';

part 'monitor_setting_json.g.dart';

@riverpod
class MonitorSettingJson extends _$MonitorSettingJson {
  StreamSubscription<FileSystemEvent>? _subscription;

  @override
  Map<String, dynamic> build(String monitorId) {
    final configDirectory = ref.watch(configDirectoryProvider);
    final file = File('${configDirectory.path}/monitor/$monitorId.json');

    _subscription?.cancel();

    // check if a file is present in the config directory
    if (!file.existsSync()) {
      _subscription =
          configDirectory.watch(events: FileSystemEvent.move).listen((event) {
        if (event is FileSystemMoveEvent) {
          if (event.destination == file.path) {
            ref.invalidateSelf();
          }
        }
      });
      return {};
    }
    _subscription = file.watch().listen((event) {
      ref.invalidateSelf();
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    try {
      return jsonDecode(
        file.readAsStringSync(),
      ) as Map<String, dynamic>;
    } on Exception catch (_) {
      return {};
    }
  }
}
