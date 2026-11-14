import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/helm/monitoring_panel/disk_monitoring/widget/disk_usage_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_battery_device.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_client.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_devices.dart';
import 'package:shell/shared/widget/shell_icon.dart';
import 'package:upower/upower.dart';

class PowerIndicator extends HookConsumerWidget {
  const PowerIndicator({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices =
        ref
            .watch(upowerDevicesProvider)
            .value
            ?.where(
              (device) =>
                  UpowerClient.getDeviceType(device) !=
                      UPowerDeviceType.linePower &&
                  !UpowerClient.isSystemBattery(device),
            ) ??
        [];
    final batteryDevice = ref.watch(upowerBatteryDeviceProvider).value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ShellIcon(
                  MdiIcons.lightningBolt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    context.l10n.power,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            if (batteryDevice != null)
              SystemBatteryIndicator(device: batteryDevice),
            for (final device in devices) DeviceIndicator(device: device),

            /* Padding(
              padding: const EdgeInsets.only(
                left: 16,
                bottom: 16,
                right: 16,
                top: 8,
              ),
              child: SegmentedButton(
                segments: const [
                  ButtonSegment(
                    icon: ShellIcon(MdiIcons.speedometerSlow),
                    value: 'power_saver',
                  ),
                  ButtonSegment(
                    icon: ShellIcon(MdiIcons.speedometerMedium),
                    value: 'balanced',
                  ),
                  ButtonSegment(
                    icon: ShellIcon(MdiIcons.speedometer),
                    value: 'performance',
                  ),
                ],
                selected: const {'balanced'},
                onSelectionChanged: (Set<String> value) {},
              ),
            ), */
          ],
        ),
      ),
    );
  }
}

class SystemBatteryIndicator extends HookWidget {
  const SystemBatteryIndicator({required this.device, super.key});
  final UPowerDevice device;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: device.propertiesChanged,
      builder: (context, snapshot) {
        return BatteryIndicator(
          icon: icon,
          label: context.l10n.battery,
          percentage: device.percentage,
        );
      },
    );
  }

  ShellIcon get icon => ShellIcon(systemBatteryIconData(device));
}

/// The glyph of the system [device]'s charge level and charging state.
IconData systemBatteryIconData(UPowerDevice device) {
  final isCharging = device.state == UPowerDeviceState.charging;
  if (isCharging) {
    return switch (device.percentage) {
      >= 90 => MdiIcons.batteryCharging100,
      >= 80 => MdiIcons.batteryCharging90,
      >= 70 => MdiIcons.batteryCharging80,
      >= 60 => MdiIcons.batteryCharging70,
      >= 50 => MdiIcons.batteryCharging60,
      >= 40 => MdiIcons.batteryCharging50,
      >= 30 => MdiIcons.batteryCharging40,
      >= 20 => MdiIcons.batteryCharging30,
      >= 10 => MdiIcons.batteryCharging20,
      _ => MdiIcons.batteryCharging10,
    };
  }
  return switch (device.percentage) {
    >= 90 => MdiIcons.battery,
    >= 80 => MdiIcons.battery90,
    >= 70 => MdiIcons.battery80,
    >= 60 => MdiIcons.battery70,
    >= 50 => MdiIcons.battery60,
    >= 40 => MdiIcons.battery50,
    >= 30 => MdiIcons.battery40,
    >= 20 => MdiIcons.battery30,
    >= 10 => MdiIcons.battery20,
    _ => MdiIcons.battery10,
  };
}

class DeviceIndicator extends StatelessWidget {
  const DeviceIndicator({required this.device, super.key});
  final UPowerDevice device;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object>(
      stream: device.propertiesChanged,
      builder: (context, snapshot) {
        return BatteryIndicator(
          icon: icon,
          label: device.model,
          percentage: device.percentage,
        );
      },
    );
  }

  ShellIcon get icon {
    switch (UpowerClient.getDeviceType(device)) {
      case UPowerDeviceType.unknown:
      case UPowerDeviceType.linePower:
      case UPowerDeviceType.battery:
      case UPowerDeviceType.ups:
        return const ShellIcon(MdiIcons.battery);
      case UPowerDeviceType.monitor:
        return const ShellIcon(MdiIcons.monitor);
      case UPowerDeviceType.mouse:
        return const ShellIcon(MdiIcons.mouse);
      case UPowerDeviceType.keyboard:
        return const ShellIcon(MdiIcons.keyboard);
      case UPowerDeviceType.pda:
        return const ShellIcon(MdiIcons.tablet);
      case UPowerDeviceType.phone:
        return const ShellIcon(MdiIcons.cellphone);
    }
  }
}

class BatteryIndicator extends StatelessWidget {
  const BatteryIndicator({
    required this.icon,
    required this.label,
    required this.percentage,
    super.key,
  });
  final ShellIcon icon;
  final String label;
  final double percentage;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 8, right: 8),
      child: Row(
        spacing: 16,
        children: [
          icon,
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodyLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // bytes to smallest integere unit
                    Text(context.l10n.percentValue(percentage)),
                  ],
                ),
                SliderTheme(
                  data: Theme.of(context).sliderTheme.copyWith(
                    thumbShape: SliderComponentShape.noThumb,
                    disabledActiveTrackColor: Theme.of(
                      context,
                    ).colorScheme.primary,
                    trackShape: CustomSliderTrackShape(),
                    trackHeight: 8,
                  ),
                  child: SizedBox(
                    height: 24,
                    child: Slider(
                      //percentage of use
                      value: percentage / 100,
                      onChanged: null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
