import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';

part 'setting_property_by_path.g.dart';

@riverpod
SettingProperty? settingPropertyByPath(Ref ref, String path) {
  final properties = ref.watch(settingsPropertiesProvider);
  final pathParts = path.split('.');
  dynamic value = properties;
  for (final part in pathParts) {
    if (value is Map) {
      value = value[part];
    } else {
      return null;
    }
  }
  if (value is SettingProperty) {
    return value;
  }
  return null;
}
