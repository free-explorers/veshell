import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/keyboard_choices.dart';
import 'package:shell/settings/model/keyboard_option.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/keyboard_layout.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';
import 'package:shell/shared/widget/list_editor.dart';

/// Trailing summary of the `keyboard.options` property: the configured
/// options, or "Not set" when the list is empty.
class KeyboardOptionsValue extends ConsumerWidget {
  const KeyboardOptionsValue({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = parseKeyboardOptions(
      ref.watch(jsonValueByPathProvider(path)),
    );
    if (options.isEmpty) return Text(context.l10n.notSet);
    final shown = options.take(2).join(', ');
    return Text(options.length > 2 ? '$shown, …' : shown);
  }
}

/// The `keyboard.options` property editor: a list of xkb options, each picked
/// from the catalogue the compositor reports.
///
/// The rows reuse the shared [ListEditor] chrome (add/delete/save, staged
/// edits) with a searchable picker per row, like the layout list. Options the
/// Caps Lock and compose key settings own are left out of the picker; a
/// hand-edited option missing from the catalogue is kept as it is.
class KeyboardOptionsEditor extends ConsumerWidget
    implements SettingPropertyValueEditor<List<String>> {
  const KeyboardOptionsEditor({
    required this.path,
    required this.property,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<List<String>> property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = parseKeyboardOptions(
      ref.watch(jsonValueByPathProvider(path)),
    );
    final available = ref.watch(availableKeyboardOptionsProvider);

    return available.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text(context.l10n.unavailable),
      data: (groups) {
        final entries = keyboardOptionEntries(groups);
        return ListEditor(
          initialValue: stored,
          itemLabel: context.l10n.keyboardOption,
          errorMessage: context.l10n.keyboardOptionInvalid,
          isValidItem: xkbOptionPattern.hasMatch,
          itemFieldBuilder: (context, controller, rebuild) =>
              _KeyboardOptionField(
                controller: controller,
                entries: entries,
                onChanged: rebuild,
              ),
          onSave: (next) {
            ref
                .read(settingsPropertiesProvider.notifier)
                .updateProperty(
                  path,
                  property.serializeValue(
                    keepLastOfExclusiveGroups(next, groups),
                  ),
                );
            ExpandableContainer.of(context).collapse();
          },
        );
      },
    );
  }
}

/// One option in the picker, labelled with its group so that, say, the many
/// "Caps Lock" entries of different groups stay apart.
@immutable
class KeyboardOptionEntry {
  const KeyboardOptionEntry({required this.group, required this.option});

  final KeyboardOptionGroup group;
  final KeyboardOption option;

  /// The readable part of the label: the group and the option.
  String get description => '${group.description}: ${option.description}';

  /// The full label, ending with the xkb code, which the picker filters on:
  /// typing either the description or the code (`grp:`) finds the option.
  String get label => '$description - ${option.name}';
}

/// The pickable options: every catalogue option but those a dedicated setting
/// owns ([curatedKeyboardOptions]), in catalogue order.
List<KeyboardOptionEntry> keyboardOptionEntries(
  List<KeyboardOptionGroup> groups,
) => [
  for (final group in groups)
    for (final option in group.options)
      if (!curatedKeyboardOptions.contains(option.name))
        KeyboardOptionEntry(group: group, option: option),
];

/// Drops all but the last of the options picked from a group that allows a
/// single option (a layout switching key, say), so a later pick replaces an
/// earlier one instead of both fighting in the keymap.
List<String> keepLastOfExclusiveGroups(
  List<String> options,
  List<KeyboardOptionGroup> groups,
) {
  final exclusiveGroupOf = <String, KeyboardOptionGroup>{
    for (final group in groups)
      if (!group.allowsMultiple)
        for (final option in group.options) option.name: group,
  };
  final lastIndexOfGroup = <KeyboardOptionGroup, int>{
    for (final (index, option) in options.indexed)
      ?exclusiveGroupOf[option]: index,
  };
  return [
    for (final (index, option) in options.indexed)
      if (exclusiveGroupOf[option] == null ||
          lastIndexOfGroup[exclusiveGroupOf[option]] == index)
        option,
  ];
}

/// A searchable dropdown over the option catalogue, bound to the row
/// controller that [ListEditor] saves.
class _KeyboardOptionField extends StatelessWidget {
  const _KeyboardOptionField({
    required this.controller,
    required this.entries,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<KeyboardOptionEntry> entries;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final dimmed = TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final current = controller.text.trim();
    KeyboardOptionEntry? selected;
    for (final entry in entries) {
      if (entry.option.name == current) {
        selected = entry;
        break;
      }
    }

    return DropdownMenu<KeyboardOptionEntry>(
      // A hand-edited option may not be in the catalogue: keep it as a hint
      // and leave the selection empty, so saving an untouched row preserves it.
      initialSelection: selected,
      hintText: selected == null && current.isNotEmpty ? current : null,
      enableFilter: true,
      requestFocusOnTap: true,
      expandedInsets: EdgeInsets.zero,
      menuHeight: 320,
      inputDecorationTheme: const InputDecorationTheme(filled: true),
      dropdownMenuEntries: [
        for (final entry in entries)
          DropdownMenuEntry<KeyboardOptionEntry>(
            value: entry,
            label: entry.label,
            // The xkb code trails the description, dimmed.
            labelWidget: Text.rich(
              TextSpan(
                text: entry.description,
                children: [
                  TextSpan(text: ' - ${entry.option.name}', style: dimmed),
                ],
              ),
            ),
          ),
      ],
      onSelected: (entry) {
        if (entry == null) return;
        controller.text = entry.option.name;
        onChanged();
      },
    );
  }
}
