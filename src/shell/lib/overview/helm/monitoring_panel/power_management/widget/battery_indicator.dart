import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/helm/monitoring_panel/disk_monitoring/widget/disk_usage_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_battery_device.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_client.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_devices.dart';
import 'package:upower/upower.dart';

class PowerIndicator extends HookConsumerWidget {
  const PowerIndicator({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(upowerDevicesProvider).value?.where(
              (device) => ![
                UPowerDeviceType.battery,
                UPowerDeviceType.linePower,
              ].contains(
                UpowerClient.getDeviceType(device),
              ),
            ) ??
        [];
    final batteryDevice = ref.watch(upowerBatteryDeviceProvider).value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    MdiIcons.lightningBolt,
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child: Text(
                      'Power',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
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
                    icon: Icon(MdiIcons.speedometerSlow),
                    value: 'power_saver',
                  ),
                  ButtonSegment(
                    icon: Icon(MdiIcons.speedometerMedium),
                    value: 'balanced',
                  ),
                  ButtonSegment(
                    icon: Icon(MdiIcons.speedometer),
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
          label: 'Battery',
          percentage: device.percentage,
        );
      },
    );
  }

  Icon get icon {
    final isCharging = device.state == UPowerDeviceState.charging;
    if (isCharging) {
      switch (device.percentage) {
        case >= 90:
          return const Icon(MdiIcons.batteryCharging100);
        case >= 80:
          return const Icon(MdiIcons.batteryCharging90);
        case >= 70:
          return const Icon(MdiIcons.batteryCharging80);
        case >= 60:
          return const Icon(MdiIcons.batteryCharging70);
        case >= 50:
          return const Icon(MdiIcons.batteryCharging60);
        case >= 40:
          return const Icon(MdiIcons.batteryCharging50);
        case >= 30:
          return const Icon(MdiIcons.batteryCharging40);
        case >= 20:
          return const Icon(MdiIcons.batteryCharging30);
        case >= 10:
          return const Icon(MdiIcons.batteryCharging20);
        default:
          return const Icon(MdiIcons.batteryCharging10);
      }
    } else {
      switch (device.percentage) {
        case >= 90:
          return const Icon(MdiIcons.battery);
        case >= 80:
          return const Icon(MdiIcons.battery90);
        case >= 70:
          return const Icon(MdiIcons.battery80);
        case >= 60:
          return const Icon(MdiIcons.battery70);
        case >= 50:
          return const Icon(MdiIcons.battery60);
        case >= 40:
          return const Icon(MdiIcons.battery50);
        case >= 30:
          return const Icon(MdiIcons.battery40);
        case >= 20:
          return const Icon(MdiIcons.battery30);
        case >= 10:
          return const Icon(MdiIcons.battery20);
        default:
          return const Icon(MdiIcons.battery10);
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

  Icon get icon {
    switch (UpowerClient.getDeviceType(device)) {
      case UPowerDeviceType.unknown:
      case UPowerDeviceType.linePower:
      case UPowerDeviceType.battery:
      case UPowerDeviceType.ups:
        return const Icon(
          MdiIcons.battery,
        );
      case UPowerDeviceType.monitor:
        return const Icon(
          MdiIcons.monitor,
        );
      case UPowerDeviceType.mouse:
        return const Icon(
          MdiIcons.mouse,
        );
      case UPowerDeviceType.keyboard:
        return const Icon(
          MdiIcons.keyboard,
        );
      case UPowerDeviceType.pda:
        return const Icon(
          MdiIcons.tablet,
        );
      case UPowerDeviceType.phone:
        return const Icon(
          MdiIcons.cellphone,
        );
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
  final Icon icon;
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
                    Text(
                      '$percentage%',
                    ),
                  ],
                ),
                SliderTheme(
                  data: Theme.of(context).sliderTheme.copyWith(
                        thumbShape: SliderComponentShape.noThumb,
                        disabledActiveTrackColor:
                            Theme.of(context).colorScheme.primary,
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
