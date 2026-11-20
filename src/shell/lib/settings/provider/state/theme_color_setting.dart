import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/provider/util/setting_definition_by_path.dart';
import 'package:shell/shared/util/logger.dart';

part 'theme_color_setting.g.dart';

const path = 'theme.color';

/// The theme color when the setting is missing or invalid: the default one
/// from the default settings.
const themeColorFallback = Color(0xFF006888);

@riverpod
Color themeColorSetting(Ref ref) {
  final property = ref.watch(settingDefinitionByPathProvider(path));
  final jsonValue = ref.watch(jsonValueByPathProvider(path));
  if (property == null ||
      property is! SettingProperty<Color> ||
      jsonValue == null) {
    return themeColorFallback;
  }
  final color = property.tryCastValue(jsonValue);
  if (color == null) {
    settingsLog.warning('Invalid theme color $jsonValue, using the default');
  }
  return color ?? themeColorFallback;
}
