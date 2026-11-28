import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/merged_settings_json.dart';
import 'package:shell/settings/provider/util/monitor_setting_json.dart';
import 'package:shell/settings/provider/util/monitor_setting_path.dart';

part 'json_value_by_path.g.dart';

@Riverpod(keepAlive: true)
dynamic jsonValueByPath(Ref ref, String path) {
  final monitorPath = parseMonitorSettingPath(path);
  final List<String> pathParts;
  dynamic value;
  if (monitorPath != null) {
    value = ref.watch(monitorSettingJsonProvider(monitorPath.monitor));
    pathParts = monitorPath.property.split('.');
  } else {
    value = ref.watch(mergedSettingsJsonProvider);
    pathParts = path.split('.');
  }
  for (final part in pathParts) {
    if (value is Map) {
      value = value[part];
    } else {
      return null;
    }
  }
  if (value != null) {
    return value;
  }
  return null;
}
