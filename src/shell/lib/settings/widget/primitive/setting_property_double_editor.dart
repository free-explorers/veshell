import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/widget/primitive/setting_value_field.dart';

class SettingPropertyDoubleEditor extends StatelessWidget
    implements SettingPropertyValueEditor<double> {
  const SettingPropertyDoubleEditor({
    required this.path,
    required this.property,
    super.key,
  });
  @override
  final String path;

  @override
  final SettingProperty<double> property;

  @override
  Widget build(BuildContext context) {
    return SettingPropertySingleValueEditor<double>(
      path: path,
      property: property,
      format: (value) => '$value',
      parse: double.tryParse,
    );
  }
}
