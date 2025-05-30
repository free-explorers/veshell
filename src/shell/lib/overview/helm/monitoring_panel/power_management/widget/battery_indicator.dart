import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_devices.dart';

class BatteryIndicator extends HookConsumerWidget {
  const BatteryIndicator({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(upowerDevicesProvider).value ?? [];
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final device in devices) Text(device.model),
          ListTile(
            leading: const Icon(
              MdiIcons.battery,
            ),
            title: SliderTheme(
              data: Theme.of(context).sliderTheme.copyWith(
                    thumbShape: SliderComponentShape.noThumb,
                    trackShape: const RoundedRectSliderTrackShape(),
                  ),
              child: const Slider(
                value: 1,
                onChanged: null,
              ),
            ),
            trailing: const Text('100%'),
          ),
          Padding(
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
          ),
        ],
      ),
    );
  }
}
