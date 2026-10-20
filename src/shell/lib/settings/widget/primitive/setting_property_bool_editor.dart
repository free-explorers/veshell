import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/screen/widget/current_screen_id.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_editor_activation.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

class SettingPropertyBoolEditor extends HookConsumerWidget
    implements SettingPropertyValueEditor<bool> {
  const SettingPropertyBoolEditor({
    required this.path,
    required this.property,
    super.key,
  });
  @override
  final String path;

  @override
  final SettingProperty<bool> property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final val = ref.watch(jsonValueByPathProvider(path)) as bool;
    void updateValue(bool newValue) {
      ref
          .read(settingsPropertiesProvider.notifier)
          .updateProperty(path, property.serializeValue(newValue));
    }

    // The boolean is edited in place, so activation from the search field
    // toggles it instead of opening an editor.
    final screenId = CurrentScreenId.maybeOf(context);
    final activation = screenId == null
        ? null
        : ref.watch(settingsEditorActivationProvider(screenId));
    useEffect(() {
      if (screenId == null || activation != path) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        updateValue(!val);
        ref
            .read(settingsEditorActivationProvider(screenId).notifier)
            .consume(path);
      });
      return null;
    }, [activation, path, screenId]);

    return SwitchListTile(
      title: Text(property.name),
      subtitle: Text(property.description),
      value: val,
      onChanged: updateValue,
    );
  }
}
