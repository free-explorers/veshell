import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/provider/memory_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/provider/memory_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/provider/processes_memory_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/widget/monitoring_card.dart';

/// Memory usage card.
class MemoryMonitoringWidget extends ConsumerWidget {
  /// Creates the memory card.
  const MemoryMonitoringWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(memoryStatsStateProvider);
    final spots = ref.watch(memoryChartProvider);
    return MonitoringCard(
      icon: MdiIcons.memory,
      title: 'Memory',
      badge: '${stats.memoryUsage}%',
      spots: spots,
      expandedBody: Consumer(
        builder: (context, ref, child) => ProcessMetricList(
          percentages: ref.watch(processesMemoryStatsProvider),
        ),
      ),
    );
  }
}
