import 'package:collection/collection.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nm/nm.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/widget/access_point_icon.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_battery_device.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/widget/battery_indicator.dart';
import 'package:shell/settings/model/keyboard_layout.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';
import 'package:shell/shared/nm/provider/nm_devices.dart';
import 'package:shell/shared/provider/now_date_time.dart';
import 'package:shell/shared/pulseaudio/provider/default_sink.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_server_info.dart';
import 'package:shell/shared/pulseaudio/provider/pulse_sink_list.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:shell/status_bar/model/clock_format.dart';
import 'package:shell/status_bar/provider/active_keyboard_layout.dart';
import 'package:shell/status_bar/provider/status_bar_settings.dart';

/// The colours of the status bar, a shade darker than the workspace panel
/// it is drawn next to.
({Color background, Color foreground}) statusBarColors(ThemeData theme) {
  final isDark = theme.colorScheme.brightness == Brightness.dark;
  final panelColor = isDark
      ? theme.colorScheme.surface
      : theme.colorScheme.primary;
  return (
    background: Color.alphaBlend(statusBarShade(theme), panelColor),
    foreground: isDark
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onPrimary,
  );
}

/// The translucent shade the status bar darkens what it is drawn over with.
Color statusBarShade(ThemeData theme) => Colors.black.withValues(
  alpha: theme.colorScheme.brightness == Brightness.dark ? 0.45 : 0.3,
);

/// The icon and text style of the status bar's items, in [foreground].
class StatusBarItemTheme extends StatelessWidget {
  const StatusBarItemTheme({
    required this.foreground,
    required this.child,
    super.key,
  });

  final Color foreground;
  final Widget child;

  @override
  Widget build(BuildContext context) => IconTheme.merge(
    data: IconThemeData(color: foreground, size: 16),
    child: DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.labelLarge!.copyWith(
        color: foreground,
        fontWeight: FontWeight.w600,
      ),
      child: child,
    ),
  );
}

/// The status icons the settings enable: keyboard layout, Wi-Fi, volume,
/// battery. Each item
/// keeps its own margin, so one with nothing to show leaves no gap.
class StatusBarIcons extends ConsumerWidget {
  const StatusBarIcons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(statusBarSettingsProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (settings.showKeyboardLayout) const _KeyboardLayoutStatus(),
        if (settings.showWifi) const _WifiStatusIcon(),
        if (settings.showVolume) const _VolumeStatusIcon(),
        if (settings.showBattery)
          _BatteryStatus(showPercentage: settings.showBatteryPercentage),
      ],
    );
  }
}

/// The time, when the settings enable it, in their format.
class StatusBarClock extends ConsumerWidget {
  const StatusBarClock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(statusBarSettingsProvider);
    if (!settings.showClock) return const SizedBox.shrink();
    return _StatusClock(format: settings.clockFormat);
  }
}

/// One item of the status bar, with the margin that separates it from the next.
class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child);
}

class _StatusClock extends HookConsumerWidget {
  const _StatusClock({required this.format});

  final ClockFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = useState(DateTime.now());
    ref.listen(nowDateTimeProvider, (prev, next) {
      if (prev?.minute != next.minute) now.value = next;
    });
    final locale = Localizations.localeOf(context).toString();
    return _StatusItem(
      child: Text(format.dateFormat(locale).format(now.value)),
    );
  }
}

class _VolumeStatusIcon extends ConsumerWidget {
  const _VolumeStatusIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The default sink is only known once the server and its sinks are.
    final isAudioReady =
        ref.watch(pulseServerInfoProvider.select((info) => info.hasValue)) &&
        ref.watch(pulseSinkListProvider.select((sinks) => sinks.hasValue));
    if (!isAudioReady) return const SizedBox.shrink();
    final sink = ref.watch(defaultPulseSinkProvider);
    if (sink == null) return const SizedBox.shrink();
    return _StatusItem(
      child: ShellIcon(switch (sink.volume) {
        _ when sink.mute => MdiIcons.volumeOff,
        <= 0 => MdiIcons.volumeOff,
        < 1 / 3 => MdiIcons.volumeLow,
        < 2 / 3 => MdiIcons.volumeMedium,
        _ => MdiIcons.volumeHigh,
      }),
    );
  }
}

class _BatteryStatus extends ConsumerWidget {
  const _BatteryStatus({required this.showPercentage});

  final bool showPercentage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden while loading, and on a machine without a system battery.
    final device = ref.watch(upowerBatteryDeviceProvider).value;
    if (device == null) return const SizedBox.shrink();
    return StreamBuilder(
      stream: device.propertiesChanged,
      builder: (context, _) => _StatusItem(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            ShellIcon(systemBatteryIconData(device)),
            if (showPercentage)
              Text(context.l10n.percentValue(device.percentage)),
          ],
        ),
      ),
    );
  }
}

/// The active keyboard layout's short label (`US`), only when several are
/// configured.
class _KeyboardLayoutStatus extends ConsumerWidget {
  const _KeyboardLayoutStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeKeyboardLayoutProvider);
    if (active == null || active.count < 2) return const SizedBox.shrink();
    final entries = parseKeyboardLayouts(
      ref.watch(jsonValueByPathProvider('keyboard.layout')) as String?,
    );
    // The configured entry, or the xkb name while the settings and the
    // compositor's keymap disagree.
    final label = active.index < entries.length
        ? keyboardLayoutLabel(entries[active.index])
        : active.name;
    return _StatusItem(child: Text(label));
  }
}

/// The connection of the first Wi-Fi device: the strength of its access
/// point, or that it is off. Hidden without a Wi-Fi device.
class _WifiStatusIcon extends ConsumerWidget {
  const _WifiStatusIcon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(nmDevicesProvider).value;
    final address = addresses?.firstWhereOrNull(
      (address) =>
          ref.read(nmDeviceProvider(address)).deviceType ==
          NetworkManagerDeviceType.wifi,
    );
    if (address == null) return const SizedBox.shrink();
    final device = ref.watch(nmDeviceProvider(address));
    final accessPoint = device.wireless?.activeAccessPoint;
    if (accessPoint == null) {
      return const _StatusItem(child: ShellIcon(MdiIcons.wifiOff));
    }
    // The device does not report its access point's strength changes.
    return StreamBuilder(
      stream: accessPoint.propertiesChanged,
      builder: (context, _) =>
          _StatusItem(child: AccessPointIcon(accessPoint: accessPoint)),
    );
  }
}
