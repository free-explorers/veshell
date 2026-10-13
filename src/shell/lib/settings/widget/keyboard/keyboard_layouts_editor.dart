import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/keyboard_layout.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/keyboard_layout.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';
import 'package:shell/shared/widget/list_editor.dart';

/// Trailing summary of the `keyboard.layout` property: the configured layouts,
/// or "Not set" when the list is empty.
class KeyboardLayoutsValue extends ConsumerWidget {
  const KeyboardLayoutsValue({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layouts = parseKeyboardLayouts(
      ref.watch(jsonValueByPathProvider(path)) as String?,
    );
    if (layouts.isEmpty) return Text(context.l10n.notSet);
    return Text(layouts.take(2).join(', '));
  }
}

/// The `keyboard.layout` property editor: a list of layouts, each picked from
/// the catalogue the compositor reports.
///
/// The rows reuse the shared [ListEditor] chrome (add/delete/save, staged edits)
/// but swap the text field for a searchable picker. The list is persisted
/// comma-separated (`us(altgr-intl),ru`), the format `XkbConfig.layout` already
/// accepts, so a hand-edited entry stays valid even when it is not in the
/// catalogue.
class KeyboardLayoutsEditor extends ConsumerWidget
    implements SettingPropertyValueEditor<String> {
  const KeyboardLayoutsEditor({
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
    final stored = parseKeyboardLayouts(
      ref.watch(jsonValueByPathProvider(path)) as String?,
    );
    final available = ref.watch(availableKeyboardLayoutsProvider);

    return available.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => Text(context.l10n.unavailable),
      data: (options) => ListEditor(
        initialValue: stored,
        itemLabel: context.l10n.layout,
        errorMessage: context.l10n.keyboardLayoutInvalid,
        itemFieldBuilder: (context, controller, rebuild) =>
            _KeyboardLayoutField(
              controller: controller,
              options: options,
              onChanged: rebuild,
            ),
        onSave: (next) {
          ref
              .read(settingsPropertiesProvider.notifier)
              .updateProperty(path, property.serializeValue(next.join(',')));
          ExpandableContainer.of(context).collapse();
        },
      ),
    );
  }
}

/// A searchable dropdown over the layout catalogue, bound to the row controller
/// that [ListEditor] saves.
class _KeyboardLayoutField extends StatelessWidget {
  const _KeyboardLayoutField({
    required this.controller,
    required this.options,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<KeyboardLayoutOption> options;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final current = controller.text.trim();
    KeyboardLayoutOption? selected;
    for (final option in options) {
      if (option.entry == current) {
        selected = option;
        break;
      }
    }

    return DropdownMenu<KeyboardLayoutOption>(
      // A hand-edited entry may not be in the catalogue: keep it as a hint and
      // leave the selection empty, so saving an untouched row preserves it.
      initialSelection: selected,
      hintText: selected == null && current.isNotEmpty ? current : null,
      label: Text(context.l10n.layout),
      enableFilter: true,
      requestFocusOnTap: true,
      expandedInsets: EdgeInsets.zero,
      menuHeight: 320,
      // The description is shown, but filtering also matches the xkb entry, so
      // typing `ru` finds Russian as well as typing its name.
      dropdownMenuEntries: [
        for (final option in options)
          DropdownMenuEntry<KeyboardLayoutOption>(
            value: option,
            label: '${option.description} (${option.entry})',
            labelWidget: Text(option.description),
          ),
      ],
      onSelected: (option) {
        if (option == null) return;
        controller.text = option.entry;
        onChanged();
      },
    );
  }
}
