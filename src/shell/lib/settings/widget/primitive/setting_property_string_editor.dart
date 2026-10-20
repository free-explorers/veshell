import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/widget/primitive/setting_value_field.dart';

class SettingPropertyStringEditor extends StatelessWidget
    implements SettingPropertyValueEditor<String> {
  const SettingPropertyStringEditor({
    required this.path,
    required this.property,
    super.key,
  });
  @override
  final String path;

  @override
  final SettingProperty<String> property;

  @override
  Widget build(BuildContext context) {
    return SettingPropertySingleValueEditor<String>(
      path: path,
      property: property,
      format: (value) => value,
      parse: (text) => text,
    );
  }
}
