import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/settings/model/types/monitor_setting.serializable.dart';
import 'package:shell/settings/provider/util/config_directory.dart';
import 'package:shell/settings/provider/util/monitor_setting_json.dart';
import 'package:shell/shared/util/file.dart';

part 'monitor_setting_state.g.dart';

@riverpod
class MonitorSettingState extends _$MonitorSettingState {
  @override
  MonitorSetting build(String monitorId) {
    final json = ref.watch(monitorSettingJsonProvider(monitorId));
    final conf = MonitorSetting.fromJson(
      json,
    );
    return conf;
  }

  void setMode(Mode mode) {
    updateFile(state.copyWith(mode: mode).toJson());
  }

  void setLocation(Offset location) {
    updateFile(state.copyWith(location: location).toJson());
  }

  void updateByPath(String path, dynamic newValue) {
    final parts = path.split('.');
    final json = state.toJson();
    dynamic current = json;
    for (var i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      if (current[part] == null) {
        current[part] = {};
      }
      current = current[part];
    }

    current[parts.last] = newValue;
    updateFile(json);
  }

  Future<void> updateFile(Map<String, dynamic> json) async {
    final configDirectory = ref.read(configDirectoryProvider);
    const encoder = JsonEncoder.withIndent('  ');
    final content = encoder.convert(json);
    print('update file $content');
    await writeFileAtomically(
      '${configDirectory.path}/monitor/$monitorId.json',
      content,
    );
  }
}
