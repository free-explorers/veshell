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

  ShellIcon get icon {
    final isCharging = device.state == UPowerDeviceState.charging;
    if (isCharging) {
      switch (device.percentage) {
        case >= 90:
          return const ShellIcon(MdiIcons.batteryCharging100);
        case >= 80:
          return const ShellIcon(MdiIcons.batteryCharging90);
        case >= 70:
          return const ShellIcon(MdiIcons.batteryCharging80);
        case >= 60:
          return const ShellIcon(MdiIcons.batteryCharging70);
        case >= 50:
          return const ShellIcon(MdiIcons.batteryCharging60);
        case >= 40:
          return const ShellIcon(MdiIcons.batteryCharging50);
        case >= 30:
          return const ShellIcon(MdiIcons.batteryCharging40);
        case >= 20:
          return const ShellIcon(MdiIcons.batteryCharging30);
        case >= 10:
          return const ShellIcon(MdiIcons.batteryCharging20);
        default:
          return const ShellIcon(MdiIcons.batteryCharging10);
      }
    } else {
      switch (device.percentage) {
        case >= 90:
          return const ShellIcon(MdiIcons.battery);
        case >= 80:
          return const ShellIcon(MdiIcons.battery90);
        case >= 70:
          return const ShellIcon(MdiIcons.battery80);
        case >= 60:
          return const ShellIcon(MdiIcons.battery70);
        case >= 50:
          return const ShellIcon(MdiIcons.battery60);
        case >= 40:
          return const ShellIcon(MdiIcons.battery50);
        case >= 30:
          return const ShellIcon(MdiIcons.battery40);
        case >= 20:
          return const ShellIcon(MdiIcons.battery30);
        case >= 10:
          return const ShellIcon(MdiIcons.battery20);
        default:
          return const ShellIcon(MdiIcons.battery10);
      }
    }
  }
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
