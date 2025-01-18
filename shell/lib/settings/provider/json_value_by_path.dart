import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/merged_settings_json.dart';

part 'json_value_by_path.g.dart';

@riverpod
String? jsonValueByPath(Ref ref, String path) {
  final json = ref.watch(mergedSettingsJsonProvider);
  final pathParts = path.split('.');
  dynamic value = json;
  for (final part in pathParts) {
    if (value is Map) {
      value = value[part];
    } else {
      return null;
    }
  }
  if (value is String) {
    return value;
  }
  return null;
}
