import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/cpu_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/cpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/processes_cpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/widget/monitoring_card.dart';

/// CPU load card.
class CpuMonitoringWidget extends ConsumerWidget {
  /// Creates the CPU card.
  const CpuMonitoringWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(cpuStatsStateProvider);
    final spots = ref.watch(cpuChartProvider);
    return MonitoringCard(
      icon: MdiIcons.chip,
      title: context.l10n.cpu,
      badge: context.l10n.percentValue(stats.cpuLoad),
      series: [
        MonitoringSeries(
          spots: spots,
          color: Theme.of(context).colorScheme.primary,
          filled: true,
        ),
      ],
      expandedBody: Consumer(
        builder: (context, ref, child) => ProcessMetricList(
          percentages: ref.watch(processesCpuStatsProvider),
        ),
      ),
    );
  }
}
