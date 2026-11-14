import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/widget/search/settings/setting_value_editor.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/settings_properties.dart';
import 'package:shell/status_bar/model/clock_format.dart';
import 'package:shell/status_bar/provider/status_bar_settings.dart';

/// Collapsed value of the `theme.statusBarContent` property: the items the
/// status bar shows.
class StatusBarContentValue extends ConsumerWidget {
  const StatusBarContentValue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(statusBarSettingsProvider);
    final items = [
      if (settings.showClock) l10n.statusBarClock,
      if (settings.showKeyboardLayout) l10n.statusBarKeyboardLayout,
      if (settings.showWifi) l10n.statusBarWifi,
      if (settings.showVolume) l10n.statusBarVolume,
      if (settings.showBattery) l10n.statusBarBattery,
    ];
    if (items.isEmpty) return Text(l10n.none);
    return Text(
      items.length > 2 ? '${items.take(2).join(', ')}, …' : items.join(', '),
    );
  }
}

/// The content of the status bar: which items it shows, and how.
class StatusBarContentEditor extends ConsumerWidget
    implements SettingPropertyValueEditor<Map<String, dynamic>> {
  const StatusBarContentEditor({
    required this.path,
    required this.property,
    super.key,
  });

  @override
  final String path;

  @override
  final SettingProperty<Map<String, dynamic>> property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(statusBarSettingsProvider);
    void update(String key, Object value) => ref
        .read(settingsPropertiesProvider.notifier)
        .updateProperty('$path.$key', value);

    Widget toggle({
      required String key,
      required String title,
      required String description,
      required bool value,
      bool enabled = true,
    }) => SwitchListTile(
      title: Text(title),
      subtitle: Text(description),
      value: value,
      onChanged: enabled ? (value) => update(key, value) : null,
    );

    // Shrinks to fit, and scrolls past the screen's height.
    return ListView(
      shrinkWrap: true,
      children: [
        toggle(
          key: 'showClock',
          title: l10n.statusBarClock,
          description: l10n.statusBarClockDescription,
          value: settings.showClock,
        ),
        ListTile(
          enabled: settings.showClock,
          title: Text(l10n.statusBarClockFormat),
          subtitle: Text(l10n.statusBarClockFormatDescription),
          trailing: DropdownButton<ClockFormat>(
            value: settings.clockFormat,
            mouseCursor: WidgetStateMouseCursor.clickable,
            dropdownMenuItemMouseCursor: WidgetStateMouseCursor.clickable,
            items: [
              for (final format in ClockFormat.values)
                DropdownMenuItem(
                  value: format,
                  child: Text(clockFormatLabel(l10n, format.name)),
                ),
            ],
            onChanged: settings.showClock
                ? (format) {
                    if (format != null) update('clockFormat', format.name);
                  }
                : null,
          ),
        ),
        toggle(
          key: 'showKeyboardLayout',
          title: l10n.statusBarKeyboardLayout,
          description: l10n.statusBarKeyboardLayoutDescription,
          value: settings.showKeyboardLayout,
        ),
        toggle(
          key: 'showWifi',
          title: l10n.statusBarWifi,
          description: l10n.statusBarWifiDescription,
          value: settings.showWifi,
        ),
        toggle(
          key: 'showVolume',
          title: l10n.statusBarVolume,
          description: l10n.statusBarVolumeDescription,
          value: settings.showVolume,
        ),
        toggle(
          key: 'showBattery',
          title: l10n.statusBarBattery,
          description: l10n.statusBarBatteryDescription,
          value: settings.showBattery,
        ),
        toggle(
          key: 'showBatteryPercentage',
          title: l10n.statusBarBatteryPercentage,
          description: l10n.statusBarBatteryPercentageDescription,
          value: settings.showBatteryPercentage,
          enabled: settings.showBattery,
        ),
      ],
    );
  }
}
