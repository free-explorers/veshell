import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/environment_variables.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';
import 'package:shell/shared/widget/key_value_map_editor.dart';

/// Trailing summary of the `environment.variables` property: the names in use,
/// or "Not set" when the map is empty.
class EnvironmentVariablesValue extends ConsumerWidget {
  const EnvironmentVariablesValue({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variables = environmentVariablesFromJson(
      ref.watch(jsonValueByPathProvider(path)),
    );
    if (variables.isEmpty) return Text(context.l10n.notSet);
    return Text(variables.keys.take(2).join(', '));
  }
}

/// The `environment.variables` property editor: the generic
/// [KeyValueMapEditor] wired to the settings store, with environment variable
/// name validation.
class EnvironmentVariablesEditor extends ConsumerWidget
    implements SettingPropertyValueEditor<Map<String, String>> {
  const EnvironmentVariablesEditor({
    required this.path,
    required this.property,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<Map<String, String>> property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = environmentVariablesFromJson(
      ref.watch(jsonValueByPathProvider(path)),
    );
    return KeyValueMapEditor(
      initialValue: stored,
      keyLabel: context.l10n.environmentVariableName,
      valueLabel: context.l10n.environmentVariableValue,
      errorMessage: context.l10n.environmentVariableInvalid,
      isValidKey: isEnvironmentVariableName,
      onSave: (variables) {
        ref
            .read(settingsPropertiesProvider.notifier)
            .updateProperty(path, variables);
        ExpandableContainer.of(context).collapse();
      },
    );
  }
}
