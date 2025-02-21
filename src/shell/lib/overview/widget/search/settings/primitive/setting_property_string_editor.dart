import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

class SettingPropertyStringEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<String> {
  const SettingPropertyStringEditor({
    required this.path,
    required this.property,
    required this.onChanged,
    super.key,
  });
  @override
  final String path;

  @override
  final SettingProperty<String> property;

  @override
  final void Function(String newValue) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final val = ref.watch(jsonValueByPathProvider(path));
    final controller = useTextEditingController(text: val);
    void updateValue(String newValue) {
      ref.read(settingsPropertiesProvider.notifier).updateProperty(
            path,
            property.serializeValue(newValue),
          );
      onChanged(newValue);
    }

    return TextField(
      controller: controller,
      autofocus: true,
      decoration: const InputDecoration(
        filled: true,
      ),
      onSubmitted: updateValue,
    );
  }
}
