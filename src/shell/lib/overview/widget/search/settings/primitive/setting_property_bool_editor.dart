import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

class SettingPropertyBoolEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<bool> {
  const SettingPropertyBoolEditor({
    required this.path,
    required this.property,
    required this.onChanged,
    super.key,
  });
  @override
  final String path;

  @override
  final SettingProperty<bool> property;

  @override
  final void Function(bool newValue) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final val = ref.watch(jsonValueByPathProvider(path)) as bool;
    void updateValue(bool newValue) {
      ref.read(settingsPropertiesProvider.notifier).updateProperty(
            path,
            property.serializeValue(newValue),
          );
      onChanged(newValue);
    }

    return SwitchListTile(
      title: Text(property.name),
      subtitle: Text(property.description),
      value: val,
      onChanged: updateValue,
    );
  }
}
