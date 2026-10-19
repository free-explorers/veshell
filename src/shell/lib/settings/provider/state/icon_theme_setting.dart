import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/settings/provider/util/setting_definition_by_path.dart';
import 'package:shell/settings/provider/util/theme_detection.dart';

part 'icon_theme_setting.g.dart';

@riverpod
String iconThemeSetting(Ref ref) {
  const path = 'theme.iconTheme';

  final property = ref.watch(settingDefinitionByPathProvider(path));
  final jsonValue = ref.watch(jsonValueByPathProvider(path));
  if (property == null ||
      property is! SettingProperty<String> ||
      jsonValue == null) {
    return detectIconTheme();
  }
  try {
    return property.castValue(jsonValue);
  } on Exception catch (e) {
    print('Failed to parse theme iconTheme: $e');
    return detectIconTheme();
  }
}
