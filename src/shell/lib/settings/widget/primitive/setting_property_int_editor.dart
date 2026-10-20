import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/widget/primitive/setting_value_field.dart';

class SettingPropertyIntEditor extends StatelessWidget
    implements SettingPropertyValueEditor<int> {
  const SettingPropertyIntEditor({
    required this.path,
    required this.property,
    super.key,
  });
  @override
  final String path;

  @override
  final SettingProperty<int> property;

  @override
  Widget build(BuildContext context) {
    return SettingPropertySingleValueEditor<int>(
      path: path,
      property: property,
      format: (value) => '$value',
      parse: int.tryParse,
    );
  }
}
