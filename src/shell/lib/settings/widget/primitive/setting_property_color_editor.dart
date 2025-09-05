import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

class SettingPropertyColorEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<Color> {
  const SettingPropertyColorEditor({
    required this.path,
    required this.property,
    super.key,
  });

  @override
  final String path;
  @override
  final SettingProperty<Color> property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final val = ref.watch(jsonValueByPathProvider(path));
    final initialValue = property.castValue(val ?? '');
    final updatedBy = useState<String?>(null);

    void updateValue(Color newValue) {
      ref.read(settingsPropertiesProvider.notifier).updateProperty(
            path,
            property.serializeValue(newValue),
          );
    }

    return Row(
      spacing: 16,
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: ColorWheelPicker(
            color: initialValue,
            onChanged: (Color color) {
              updateValue(color);
              updatedBy.value = 'wheel';
            },
            onWheel: (value) {},
            shouldUpdate: updatedBy.value != 'wheel',
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Row(
              spacing: 8,
              children: [
                const Color(0xFF006888),
                const Color(0xFFB71C1C),
                const Color(0xFF2E7D32),
                const Color(0xFFC51162),
                const Color(0xFFD8DEE9),
              ]
                  .map(
                    (Color color) => ColorIndicator(
                      color: color,
                      onSelect: () {
                        updateValue(color);
                        updatedBy.value = 'indicator';
                      },
                      isSelected: initialValue == color,
                    ),
                  )
                  .toList(),
            ),
            ColorCodeField(
              color: initialValue,
              onColorChanged: (color) {
                updateValue(color);
                updatedBy.value = 'code';
              },
              onEditFocused: (bool) {},
              requestFocus: false,
              focusedEditHasNoColor: false,
              colorCodeHasColor: true,
              shouldUpdate: updatedBy.value != 'code',
            ),
          ],
        ),
      ],
    );
  }
}
