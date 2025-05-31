import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/shared/widget/expandable_container.dart';
import 'package:shell/shared/widget/hotkey_viewer.dart';

class SettingPropertyHotkeyEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<LogicalKeySet> {
  const SettingPropertyHotkeyEditor({
    required this.path,
    required this.property,
    required this.onChanged,
    super.key,
  });
  @override
  final String path;

  @override
  final SettingProperty<LogicalKeySet> property;

  @override
  final void Function(LogicalKeySet newValue) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keysPressed = useState<Set<LogicalKeyboardKey>>({});
    final pressedNum = useState<int>(0);
    final focusNode = useFocusNode();
    void updateValue(LogicalKeySet newValue) {
      ref.read(settingsPropertiesProvider.notifier).updateProperty(
            path,
            property.serializeValue(newValue),
          );
      onChanged(newValue);
    }

    return Focus(
      autofocus: true,
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.escape &&
            keysPressed.value.isEmpty) {
          ExpandableContainer.of(context).toggle();
          focusNode.unfocus();

          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          updateValue(LogicalKeySet.fromSet(keysPressed.value));
          focusNode.unfocus();
          ExpandableContainer.of(context).toggle();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent) {
          if (pressedNum.value == 0) {
            keysPressed.value = {};
          }
          keysPressed.value = {...keysPressed.value, event.logicalKey};
          pressedNum.value++;
        }
        if (event is KeyUpEvent) {
          pressedNum.value--;
        }
        return KeyEventResult.handled;
      },
      child: keysPressed.value.isEmpty
          ? const Text('Press any key')
          : HotkeyViewer(
              hotkey: LogicalKeySet.fromSet(keysPressed.value),
            ),
    );
  }
}
