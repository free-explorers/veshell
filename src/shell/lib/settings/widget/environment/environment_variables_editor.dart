import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/environment_variables.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';

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

/// Editable list of environment variable names and values.
///
/// Edits are staged locally and written once through the settings provider, so
/// a half-typed name never lands in `settings.json`; an empty row is skipped,
/// a malformed or duplicated name blocks the save with an inline message.
class EnvironmentVariablesEditor extends HookConsumerWidget
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
    final variables = useState(
      useMemoized(
        () => [
          for (final entry in stored.entries)
            _DraftVariable(name: entry.key, value: entry.value),
        ],
      ),
    );
    final invalid = useState(false);

    useEffect(
      () => () {
        for (final variable in variables.value) {
          variable.dispose();
        }
      },
      const [],
    );

    void add() {
      variables.value = [...variables.value, _DraftVariable()];
      invalid.value = false;
    }

    void remove(_DraftVariable variable) {
      variables.value = variables.value
          .where((entry) => entry != variable)
          .toList();
      variable.dispose();
      invalid.value = false;
    }

    void save() {
      final next = <String, String>{};
      for (final variable in variables.value) {
        final name = variable.nameController.text.trim();
        final value = variable.valueController.text;
        // A fully blank row is a leftover of "Add"; ignore it.
        if (name.isEmpty && value.isEmpty) continue;
        if (!isEnvironmentVariableName(name) || next.containsKey(name)) {
          invalid.value = true;
          return;
        }
        next[name] = value;
      }
      ref.read(settingsPropertiesProvider.notifier).updateProperty(path, next);
      ExpandableContainer.of(context).collapse();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final variable in variables.value)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: TextField(
                    controller: variable.nameController,
                    decoration: InputDecoration(
                      filled: true,
                      labelText: context.l10n.environmentVariableName,
                    ),
                    onChanged: (_) => invalid.value = false,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: variable.valueController,
                    decoration: InputDecoration(
                      filled: true,
                      labelText: context.l10n.environmentVariableValue,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(MdiIcons.delete),
                  tooltip: context.l10n.delete,
                  onPressed: () => remove(variable),
                ),
              ],
            ),
          ),
        if (invalid.value)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.l10n.environmentVariableInvalid,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Row(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: add,
              icon: const Icon(MdiIcons.plus),
              label: Text(context.l10n.add),
            ),
            const Spacer(),
            FilledButton(onPressed: save, child: Text(context.l10n.save)),
          ],
        ),
      ],
    );
  }
}

/// One staged row in the editor, owning its text controllers.
class _DraftVariable {
  _DraftVariable({String name = '', String value = ''})
    : nameController = TextEditingController(text: name),
      valueController = TextEditingController(text: value);

  final TextEditingController nameController;
  final TextEditingController valueController;

  void dispose() {
    nameController.dispose();
    valueController.dispose();
  }
}
