import 'dart:ui';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/provider/util/setting_definition_by_path.dart';

part 'theme_color_setting.g.dart';

@riverpod
Color themeColorSetting(Ref ref) {
  const path = 'theme.color';
  const fallback = Color(0xFF434C5E);

  final property = ref.watch(settingDefinitionByPathProvider(path));
  final jsonValue = ref.watch(jsonValueByPathProvider(path));
  if (property == null ||
      property is! SettingProperty<Color> ||
      jsonValue == null) {
    return fallback;
  }
  try {
    return property.castValue(jsonValue);
  } on Exception catch (e) {
    print('Failed to parse theme color: $e');
    return fallback;
  }
}
