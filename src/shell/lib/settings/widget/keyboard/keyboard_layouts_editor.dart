import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';

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

/// Edits `keyboard.layout` as a list of xkb layouts.
///
/// The list is persisted comma-separated, the format `XkbConfig.layout` (and
/// `localectl`/`setxkbmap`) already use. The compositor compiles every entry
/// into a single keymap, so `toggleKeyboardLayout` can cycle through them.
class KeyboardLayoutsEditor extends HookConsumerWidget
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
    final value = ref.watch(jsonValueByPathProvider(path)) as String?;
    // Seed the fields once; `useMemoized` keeps the same controllers across
    // rebuilds, and `revision` forces a rebuild when the list is mutated.
    final controllers = useMemoized<List<TextEditingController>>(
      () => [
        for (final layout in parseKeyboardLayouts(value))
          TextEditingController(text: layout),
      ],
    );
    final revision = useState(0);
    void refresh() => revision.value++;

    useEffect(() {
      return () {
        for (final controller in controllers) {
          controller.dispose();
        }
      };
    }, const []);

    void addLayout() {
      controllers.add(TextEditingController());
      refresh();
    }

    void removeLayout(int index) {
      controllers.removeAt(index).dispose();
      refresh();
    }

    void save() {
      final layouts = controllers
          .map((controller) => controller.text.trim())
          .where((layout) => layout.isNotEmpty)
          .toList();
      ref
          .read(settingsPropertiesProvider.notifier)
          .updateProperty(path, property.serializeValue(layouts.join(',')));
      ExpandableContainer.of(context).toggle();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < controllers.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              spacing: 16,
              children: [
                Expanded(
                  child: TextField(
                    controller: controllers[index],
                    autofocus: index == controllers.length - 1,
                    decoration: const InputDecoration(filled: true),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.delete,
                  icon: const Icon(MdiIcons.close),
                  onPressed: controllers.length > 1
                      ? () => removeLayout(index)
                      : null,
                ),
              ],
            ),
          ),
        Row(
          spacing: 16,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: addLayout,
                icon: const Icon(MdiIcons.plus),
                label: Text(context.l10n.addLayout),
              ),
            ),
            IconButton(
              tooltip: context.l10n.apply,
              icon: const Icon(MdiIcons.check),
              onPressed: save,
            ),
          ],
        ),
      ],
    );
  }
}
