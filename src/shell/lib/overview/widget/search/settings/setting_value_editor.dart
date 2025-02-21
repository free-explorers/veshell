import 'package:shell/settings/model/setting_property.dart';

abstract class SettingPropertyValueEditor<T> {
  const SettingPropertyValueEditor({
    required this.path,
    required this.property,
    required this.onChanged,
  });

  final String path;
  final SettingProperty<T> property;
  final void Function(T newValue) onChanged;
}
