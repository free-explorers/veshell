import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';
import 'package:shell/shared/widget/list_editor.dart';

/// Splits the stored comma-separated xkb layout list into its entries.
///
/// The value is xkb-native (`us(altgr-intl),ru`): a layout may carry its
/// variant in parentheses, and a variant never contains a comma, so
/// splitting on commas recovers one entry per layout.
List<String> parseKeyboardLayouts(String? value) {
  if (value == null) return const [];
  return value
      .split(',')
      .map((layout) => layout.trim())
      .where((layout) => layout.isNotEmpty)
      .toList();
}

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

/// The `keyboard.layout` property editor: the generic [ListEditor] wired to the
/// settings store.
///
/// Each entry is one xkb layout, optionally with a variant (`us(altgr-intl)`);
/// the list is persisted comma-separated, the format `XkbConfig.layout` (and
/// `localectl`/`setxkbmap`) already use. The compositor compiles every entry
/// into one keymap, so `toggleKeyboardLayout` can cycle through them.
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
    final layouts = parseKeyboardLayouts(
      ref.watch(jsonValueByPathProvider(path)) as String?,
    );
    return ListEditor(
      initialValue: layouts,
      itemLabel: context.l10n.layout,
      errorMessage: context.l10n.keyboardLayoutInvalid,
      onSave: (next) {
        ref
            .read(settingsPropertiesProvider.notifier)
            .updateProperty(path, property.serializeValue(next.join(',')));
        ExpandableContainer.of(context).collapse();
      },
    );
  }
}
