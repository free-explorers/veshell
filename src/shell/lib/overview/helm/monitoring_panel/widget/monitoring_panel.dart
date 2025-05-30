import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/widget/cpu_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/disk_monitoring/widget/disk_usage_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/widget/memory_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/any_upower_device.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/widget/battery_indicator.dart';

class MonitoringPanel extends HookConsumerWidget {
  const MonitoringPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Battery level
        // Disk usages
        // CPU loading
        // Memory loading
        // Network usage
        if (ref.watch(anyUpowerDeviceProvider)) const PowerIndicator(),
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
