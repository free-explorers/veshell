import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/widget/expandable_container.dart';

/// The Caps Lock behaviors, in the order shown in the picker. The value is the
/// settings string and matches `CapsLockBehavior` in the compositor.
const capsLockBehaviors = <String>[
  'default',
  'control',
  'escape',
  'swapescape',
  'disabled',
];

/// The localized label for a Caps Lock behavior string.
String capsLockLabel(AppLocalizations l10n, String value) => switch (value) {
  'control' => l10n.capsLockControl,
  'escape' => l10n.capsLockEscape,
  'swapescape' => l10n.capsLockSwapescape,
  'disabled' => l10n.capsLockDisabled,
  _ => l10n.capsLockDefault,
};

/// Trailing summary of the `keyboard.capsLock` property.
class CapsLockValue extends ConsumerWidget {
  const CapsLockValue({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value =
        ref.watch(jsonValueByPathProvider(path)) as String? ?? 'default';
    return Text(capsLockLabel(context.l10n, value));
  }
}

/// Picks what the Caps Lock key does.
///
/// The choice is applied as an xkb option on the seat keymap, so both the shell
/// and forwarded clients see the remap; it is not a shell-side key rewrite.
class SettingPropertyCapsLockEditor extends ConsumerWidget
    implements SettingPropertyValueEditor<String> {
  const SettingPropertyCapsLockEditor({
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
    final current =
        ref.watch(jsonValueByPathProvider(path)) as String? ?? 'default';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final behavior in capsLockBehaviors)
          ListTile(
            title: Text(capsLockLabel(context.l10n, behavior)),
            trailing: behavior == current ? const Icon(Icons.check) : null,
            onTap: () {
              ref
                  .read(settingsPropertiesProvider.notifier)
                  .updateProperty(path, property.serializeValue(behavior));
              ExpandableContainer.of(context).toggle();
            },
          ),
      ],
    );
  }
}
