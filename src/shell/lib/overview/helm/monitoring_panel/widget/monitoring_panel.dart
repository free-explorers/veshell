import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/widget/cpu_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/disk_monitoring/widget/disk_usage_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/widget/gpu_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/widget/memory_monitoring.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/any_upower_device.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/widget/battery_indicator.dart';
import 'package:shell/overview/helm/widget/panel_column.dart';

/// The monitoring cards: battery (when present), CPU, memory, GPU (when a
/// supported card is present) and disk.
///
/// The cards are grouped in a [Column] with the shared [panelGap] so they keep
/// the same spacing as any other card in the panel.
Widget monitoringSection(WidgetRef ref) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    spacing: panelGap,
    children: [
      if (ref.watch(anyUpowerDeviceProvider)) const PowerIndicator(),
      const CpuMonitoringWidget(),
      const MemoryMonitoringWidget(),
      if (ref.watch(gpuDeviceProvider) != null) const GpuMonitoringWidget(),
      const DiskUsageMonitoring(),
    ],
  );
}
