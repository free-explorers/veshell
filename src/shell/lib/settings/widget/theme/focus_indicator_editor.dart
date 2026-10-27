import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/settings/provider/state/focus_indicator_setting.dart';
import 'package:shell/shared/widget/expandable_container.dart';

/// The localized label for a focus indicator.
String focusIndicatorLabel(AppLocalizations l10n, FocusIndicator value) =>
    switch (value) {
      FocusIndicator.border => l10n.focusIndicatorBorder,
      FocusIndicator.grayscale => l10n.focusIndicatorGrayscale,
      FocusIndicator.none => l10n.focusIndicatorNone,
    };

/// Trailing summary of the `theme.focusIndicator` property.
class FocusIndicatorValue extends ConsumerWidget {
  const FocusIndicatorValue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(focusIndicatorSettingProvider);
    return Text(focusIndicatorLabel(context.l10n, value));
  }
}

/// Picks how the focused tile stands out when several tiles are visible.
class FocusIndicatorEditor extends ConsumerWidget
    implements SettingPropertyValueEditor<String> {
  const FocusIndicatorEditor({
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
    final current = ref.watch(focusIndicatorSettingProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final indicator in FocusIndicator.values)
          ListTile(
            title: Text(focusIndicatorLabel(context.l10n, indicator)),
            trailing: indicator == current ? const Icon(Icons.check) : null,
            onTap: () {
              ref
                  .read(settingsPropertiesProvider.notifier)
                  .updateProperty(
                    path,
                    property.serializeValue(indicator.name),
                  );
              ExpandableContainer.of(context).toggle();
            },
          ),
      ],
    );
  }
}
