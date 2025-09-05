import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';

class SettingPropertyStringEditor extends HookConsumerWidget
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
  Widget build(BuildContext context, WidgetRef ref) {
    final val = ref.watch(jsonValueByPathProvider(path)) as String;
    final controller = useTextEditingController(text: val);
    void updateValue(String newValue) {
      ref.read(settingsPropertiesProvider.notifier).updateProperty(
            path,
            property.serializeValue(newValue),
          );
      ExpandableContainer.of(context).toggle();
    }

    return Row(
      spacing: 16,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              filled: true,
            ),
            onSubmitted: updateValue,
          ),
        ),
        IconButton(
          icon: const Icon(MdiIcons.check),
          onPressed: () => updateValue(controller.text),
        ),
      ],
    );
  }
}
