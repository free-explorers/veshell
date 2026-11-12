import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';
import 'package:shell/shared/widget/shell_icon.dart';

/// The localized label of one choice of a string setting.
typedef ChoiceLabel = String Function(AppLocalizations l10n, String value);

/// Trailing summary of a string setting picked from fixed [choices]: the label
/// of the stored value, or of [defaultValue] when it is unset or unknown.
class SettingPropertyChoiceValue extends ConsumerWidget {
  const SettingPropertyChoiceValue({
    required this.path,
    required this.choices,
    required this.defaultValue,
    required this.label,
    super.key,
  });

  final String path;
  final List<String> choices;
  final String defaultValue;
  final ChoiceLabel label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = currentChoice(ref, path, choices, defaultValue);
    return Text(label(context.l10n, value));
  }
}

/// Picks a string setting from fixed [choices], one row each, checking the
/// stored one; picking a row saves it and folds the editor. The list scrolls
/// when it outgrows the room the expanded editor has.
class SettingPropertyChoiceEditor extends ConsumerWidget
    implements SettingPropertyValueEditor<String> {
  const SettingPropertyChoiceEditor({
    required this.path,
    required this.property,
    required this.choices,
    required this.defaultValue,
    required this.label,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<String> property;

  final List<String> choices;
  final String defaultValue;
  final ChoiceLabel label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = currentChoice(ref, path, choices, defaultValue);
    // The expanded editor only gets the room left below its row, which a long
    // list of choices can outgrow: shrink to fit, scroll past it.
    return ListView(
      shrinkWrap: true,
      children: [
        for (final choice in choices)
          ListTile(
            title: Text(label(context.l10n, choice)),
            trailing: choice == current
                ? const ShellIcon(MdiIcons.check)
                : null,
            onTap: () {
              ref
                  .read(settingsPropertiesProvider.notifier)
                  .updateProperty(path, property.serializeValue(choice));
              ExpandableContainer.of(context).toggle();
            },
          ),
      ],
    );
  }
}

/// The stored choice at [path], or [defaultValue] when it is unset or not
/// one of [choices] (the compositor reads an unknown value as the default).
String currentChoice(
  WidgetRef ref,
  String path,
  List<String> choices,
  String defaultValue,
) {
  final value = ref.watch(jsonValueByPathProvider(path));
  return value is String && choices.contains(value) ? value : defaultValue;
}
