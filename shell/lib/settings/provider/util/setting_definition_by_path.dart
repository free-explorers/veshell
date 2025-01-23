import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/model/setting_definition.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/provider/settings_properties.dart';

part 'setting_definition_by_path.g.dart';

@riverpod
SettingDefinition? settingDefinitionByPath(Ref ref, String path) {
  final properties = ref.watch(settingsPropertiesProvider);
  final pathParts = path.split('.');
  dynamic value = properties;
  for (final part in pathParts) {
    if (value is Map) {
      value = value[part];
    } else if (value is SettingGroup) {
      value = value.children[part];
    } else {
      return null;
    }
  }
  if (value is SettingDefinition) {
    return value;
  }
  return null;
}
