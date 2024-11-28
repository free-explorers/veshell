import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/widget/cpu_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/disk_monitoring/widget/disk_usage_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/widget/memory_monitoring.dart';

class MonitoringPanel extends StatelessWidget {
  const MonitoringPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Battery level
        // Disk usages
        // CPU loading
        // Memory loading
        // Network usage

        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
        ),
        const Flexible(
          child: CpuMonitoringWidget(),
        ),
        const Flexible(
          child: MemoryMonitoringWidget(),
        ),
        const DiskUsageMonitoring(),
      ],
    );
  }
}
