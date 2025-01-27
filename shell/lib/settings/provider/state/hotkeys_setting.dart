import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/provider/util/setting_definition_by_path.dart';

part 'hotkeys_setting.g.dart';

@riverpod
Map<String, LogicalKeySet> hotkeysSetting(Ref ref) {
  const path = 'keyboard.hotkeys';
  const fallback = <String, LogicalKeySet>{};

  final group = ref.watch(settingDefinitionByPathProvider(path));
  if (group == null || group is! SettingGroup) {
    return fallback;
  }
  final hotkeys = <String, LogicalKeySet>{};
  for (final entry in group.children.entries) {
    final actionId = entry.key;
    final property = entry.value;
    if (property is! SettingProperty<LogicalKeySet>) {
      continue;
    }
    final jsonValue = ref.watch(jsonValueByPathProvider('$path.$actionId'));
    hotkeys[actionId] = property.castValue(jsonValue ?? '');
  }
  return hotkeys;
}
