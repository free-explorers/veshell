import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/merged_settings_json.dart';
import 'package:shell/settings/provider/util/monitor_setting_json.dart';

part 'json_value_by_path.g.dart';

@riverpod
dynamic jsonValueByPath(Ref ref, String path) {
  final pathParts = path.split('.');
  dynamic value;
  if (pathParts.first == 'monitors') {
    value = ref.watch(monitorSettingJsonProvider(pathParts[1]));
    pathParts.removeRange(0, 2);
  } else {
    value = ref.watch(mergedSettingsJsonProvider);
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
