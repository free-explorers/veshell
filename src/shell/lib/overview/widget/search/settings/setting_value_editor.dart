import 'package:shell/settings/model/setting_property.dart';

abstract class SettingPropertyValueEditor<T> {
  const SettingPropertyValueEditor({
    required this.path,
    required this.property,
  });

  final String path;
  final SettingProperty<T> property;
}
