import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/provider/util/setting_definition_by_path.dart';

part 'battery_threshold_setting.g.dart';

/// Path of the low-battery warning threshold (percentage).
const batteryLowThresholdPath = 'notifications.batteryLowThreshold';

/// Path of the critical-battery warning threshold (percentage).
const batteryCriticalThresholdPath = 'notifications.batteryCriticalThreshold';

/// Defaults mirror `extra/settings/default/settings.json`.
const batteryLowThresholdFallback = 20;
const batteryCriticalThresholdFallback = 10;

@riverpod
int batteryLowThresholdSetting(Ref ref) =>
    _intSetting(ref, batteryLowThresholdPath, batteryLowThresholdFallback);

@riverpod
int batteryCriticalThresholdSetting(Ref ref) => _intSetting(
  ref,
  batteryCriticalThresholdPath,
  batteryCriticalThresholdFallback,
);

/// Reads an integer setting, falling back when the property is missing or the
/// stored value cannot be cast.
int _intSetting(Ref ref, String path, int fallback) {
  final property = ref.watch(settingDefinitionByPathProvider(path));
  final jsonValue = ref.watch(jsonValueByPathProvider(path));
  if (property is SettingProperty<int> && jsonValue != null) {
    final value = property.tryCastValue(jsonValue);
    if (value != null) {
      return value;
    }
  }
  return fallback;
}
