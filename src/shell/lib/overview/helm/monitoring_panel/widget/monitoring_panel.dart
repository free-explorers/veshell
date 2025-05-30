import 'package:flutter/material.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/widget/cpu_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/disk_monitoring/widget/disk_usage_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/widget/memory_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/widget/battery_indicator.dart';

class MonitoringPanel extends StatelessWidget {
  const MonitoringPanel({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        // Battery level
        // Disk usages
        // CPU loading
        // Memory loading
        // Network usage
        BatteryIndicator(),
        Flexible(
          child: CpuMonitoringWidget(),
        ),
        Flexible(
          child: MemoryMonitoringWidget(),
        ),
        DiskUsageMonitoring(),
      ],
    );
  }
}
