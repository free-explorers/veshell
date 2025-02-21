import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/monitor_by_name.dart';
import 'package:shell/settings/model/types/monitor_configuration.serializable.dart';
import 'package:shell/settings/provider/util/config_directory.dart';
import 'package:shell/shared/util/file.dart';

part 'monitor_setting.g.dart';

@riverpod
class MonitorSetting extends _$MonitorSetting {
  StreamSubscription<FileSystemEvent>? _subscription;

  @override
  MonitorConfiguration build(String monitorId) {
    final monitor = ref.watch(monitorByNameProvider(monitorId));
    final configDirectory = ref.watch(configDirectoryProvider);
    final file = File('${configDirectory.path}/monitor/$monitorId.json');
    // check if a file is present in the config directory
    if (!file.existsSync()) {
      _subscription =
          configDirectory.watch(events: FileSystemEvent.create).listen((event) {
        if (event.path == file.path) {
          ref.invalidateSelf();
        }
      });
      return MonitorConfiguration(
        mode: monitor!.currentMode!,
        location: monitor.location,
      );
    }
    _subscription = file.watch().listen((event) {
      ref.invalidateSelf();
    });
    return MonitorConfiguration.fromJson(
      jsonDecode(
        file.readAsStringSync(),
      ) as Map<String, dynamic>,
    );
  }

  void setMode(Mode mode) {
    updateFile(state.copyWith(mode: mode));
  }

  void setLocation(Offset location) {
    updateFile(state.copyWith(location: location));
  }

  Future<void> updateFile(MonitorConfiguration configuration) async {
    final configDirectory = ref.read(configDirectoryProvider);
    const encoder = JsonEncoder.withIndent('  ');
    final content = encoder.convert(configuration.toJson());
    print('update file $content');
    await writeFileAtomically(
      '${configDirectory.path}/monitor/$monitorId.json',
      content,
    );
  }
}
