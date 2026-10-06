import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/l10n/l10n.dart';
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
  /// Fields owned by the confirmation guard.
  ///
  /// Location and mirroring are written directly and are deliberately absent:
  /// they must survive a rollback of a guarded change. See
  /// `docs/specifications/monitor.md` (section "Change confirmation").
  static const _guardedFields = <String>[
    'mode',
    'fractionnalScale',
    'transform',
  ];

  @override
  MonitorSetting build(String monitorId) {
    final json = ref.watch(monitorSettingJsonProvider(monitorId));
    final conf = MonitorSetting.fromJson(json);
    return conf;
  }

  void setMode(Mode mode) {
    _applyGuarded((current) => current.copyWith(mode: mode), 'mode');
  }

  void setLocation(Offset location) {
    _applyDirect((current) => current.copyWith(location: location));
  }

  void setTransform(MonitorTransform transform) {
    _applyGuarded(
      (current) => current.copyWith(transform: transform),
      'transform',
    );
  }

  void setMirrorOf(String? monitorId) {
    _applyDirect((current) => current.copyWith(mirrorOf: monitorId));
  }

  void updateByPath(String path, dynamic newValue) {
    final parts = path.split('.');
    final current = state;
    final json = current.toJson();
    dynamic cursor = json;
    for (var i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      if (cursor[part] == null) {
        cursor[part] = {};
      }
      cursor = cursor[part];
    }

    cursor[parts.last] = newValue;
    final next = MonitorSetting.fromJson(json);
    if (next == current) {
      return;
    }
    state = next;
    _proposeChange(current, next, parts.last);
  }

  /// Applies a guarded change (mode, scale, transform) through the confirmation
  /// guard, unless it is a no-op.
  ///
  /// [change] is applied to the notifier's state, which is updated
  /// optimistically before the write: the change is applied live, and the next
  /// edit must build on it rather than on a value the file watcher has not
  /// published yet.
  void _applyGuarded(
    MonitorSetting Function(MonitorSetting) change,
    String description,
  ) {
    final previous = state;
    final next = change(previous);
    if (next == previous) {
      return;
    }
    state = next;
    _proposeChange(previous, next, description);
  }

  void _proposeChange(
    MonitorSetting previous,
    MonitorSetting next,
    String description,
  ) {
    final l10n = ref.read(shellLocalizationsProvider);
    final setting = switch (description) {
      'mode' => l10n.resolution,
      'fractionnalScale' => l10n.fractionalScale,
      'transform' => l10n.transform,
      _ => description,
    };
    ref
        .read(monitorSettingChangeConfirmationProvider.notifier)
        .propose(
          monitorId: monitorId,
          description: l10n.monitorSettingChanged(setting, monitorId),
          previous: previous.toJson(),
          next: next.toJson(),
        );
  }

  /// Applies a direct change (location, mirroring), unless it is a no-op.
  ///
  /// Direct changes are not guarded, but they still update the state before
  /// writing so the next edit never resurrects a value the write replaced.
  void _applyDirect(MonitorSetting Function(MonitorSetting) change) {
    final previous = state;
    final next = change(previous);
    if (next == previous) {
      return;
    }
    state = next;
    unawaited(updateFile(next.toJson()));
  }

  /// Restores the guarded fields from [previous] while keeping the current
  /// location and mirror target, then persists the result.
  ///
  /// Called by the confirmation rollback: only mode, scale and transform are
  /// reverted, so a location or mirror change made while a guarded change was
  /// pending is not lost. See `docs/specifications/monitor.md`.
  void restoreGuarded(Map<String, dynamic> previous) {
    final json = state.toJson();
    for (final field in _guardedFields) {
      if (previous.containsKey(field)) {
        json[field] = previous[field];
      }
    }
    final restored = MonitorSetting.fromJson(json);
    state = restored;
    unawaited(updateFile(restored.toJson()));
  }

  /// Replaces the persisted geometry with [json].
  ///
  /// The confirmation guard writes the live change and the rollback through
  /// this method; it is the only path that touches `monitor/<monitorId>.json`.
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
