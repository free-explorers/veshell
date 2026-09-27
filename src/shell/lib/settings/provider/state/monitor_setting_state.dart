import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/settings/model/types/monitor_setting.serializable.dart';
import 'package:shell/settings/provider/state/monitor_setting_change_confirmation.dart';
import 'package:shell/settings/provider/util/config_directory.dart';
import 'package:shell/settings/provider/util/monitor_setting_json.dart';
import 'package:shell/shared/util/file.dart';

part 'monitor_setting_state.g.dart';

/// Single writer of the desired geometry for one monitor.
///
/// Persists `monitor/<monitorId>.json`, the authoritative desired mode, scale
/// and location that Rust's `SettingsManager` applies at connect time. This is
/// the Flutter side of the ownership model in
/// `docs/specifications/monitor.md` (section "State ownership").
///
/// Settings that can leave a monitor unusable (mode, scale, transform) go
/// through [MonitorSettingChangeConfirmation]: the change is applied at once
/// and only kept if the user confirms it before the countdown expires.
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
    _propose(state.copyWith(mode: mode), 'Resolution');
  }

  void setLocation(Offset location) {
    updateFile(state.copyWith(location: location).toJson());
  }

  void setTransform(MonitorTransform transform) {
    _propose(state.copyWith(transform: transform), 'Transform');
  }

  void setMirrorOf(String? monitorId) {
    updateFile(state.copyWith(mirrorOf: monitorId).toJson());
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
    _propose(MonitorSetting.fromJson(json), parts.last);
  }

  /// Applies [next] through the confirmation guard, unless it is a no-op.
  void _propose(MonitorSetting next, String description) {
    if (next == state) {
      return;
    }
    ref
        .read(monitorSettingChangeConfirmationProvider.notifier)
        .propose(
          monitorId: monitorId,
          description: '$description of $monitorId',
          previous: state.toJson(),
          next: next.toJson(),
        );
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
