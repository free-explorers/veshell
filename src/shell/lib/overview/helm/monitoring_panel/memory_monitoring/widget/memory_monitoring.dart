import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
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
      title: context.l10n.memory,
      badge: context.l10n.percentValue(stats.memoryUsage),
      series: [
        MonitoringSeries(
          spots: spots,
          color: Theme.of(context).colorScheme.primary,
          filled: true,
        ),
      ],
      expandedBody: Consumer(
        builder: (context, ref, child) => ProcessMetricList(
          percentages: ref.watch(processesMemoryStatsProvider),
        ),
      ),
    );
  }
}
