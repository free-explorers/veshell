import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/cpu_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/cpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/processes_cpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/provider/process_name.dart';
import 'package:shell/shared/widget/expandable_card.dart';

class CpuMonitoringWidget extends HookConsumerWidget {
  const CpuMonitoringWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(cpuStatsStateProvider);
    final cpuChartData = ref.watch(cpuChartProvider);
    return ExpandableCard(
      builder: (context, isExpanded) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: isExpanded ? 400 : double.infinity,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Positioned.fill(
                    child: LineChart(
                      LineChartData(
                        minX: cpuChartData.firstOrNull?.x ?? 0,
                        maxX: cpuChartData.lastOrNull?.x ?? 0,
                        maxY: 100,
                        minY: 0,
                        gridData: const FlGridData(
                          show: false,
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(
                          show: false,
                        ),
                        lineTouchData: const LineTouchData(
                          enabled: false,
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: cpuChartData,
                            dotData: const FlDotData(
                              show: false,
                            ),
                            barWidth: 0,
                            isCurved: true,
                            curveSmoothness: 0.1,
                            color: Theme.of(context).colorScheme.primary,
                            belowBarData: BarAreaData(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withAlpha(100),
                              show: true,
                            ),
                          ),
                        ],
                      ),
                      duration: Duration.zero,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          MdiIcons.chip,
                        ),
                        const SizedBox(
                          width: 16,
                        ),
                        Expanded(
                          child: Text(
                            'Cpu',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Card(
                          color: Theme.of(context).colorScheme.primary,
                          child: SizedBox(
                            height: 32,
                            width: 56,
                            child: Center(
                              child: Text(
                                '${stats.cpuLoad}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium!
                                    .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        IconButton.filledTonal(
                          onPressed: () {
                            ExpandableCard.of(context).toggle();
                          },
                          icon: Icon(
                            isExpanded
                                ? MdiIcons.chevronUp
                                : MdiIcons.chevronDown,
                          ),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(0),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isExpanded)
                const Divider(
                  height: 2,
                ),
              if (isExpanded)
                Consumer(
                  builder: (context, ref, child) {
                    final processesStats = ref.watch(processesCpuStatsProvider);
                    final sortedProcessList =
                        processesStats.toEntryIList().sort(
                              (a, b) => b.value == a.value
                                  ? b.key.compareTo(a.key)
                                  : b.value.compareTo(a.value),
                            );
                    return Expanded(
                      child: ColoredBox(
                        color: Colors.black12,
                        child: ListView.builder(
                          itemCount: sortedProcessList.length,
                          itemBuilder: (context, index) => Consumer(
                            builder: (context, ref, child) {
                              final processStat = sortedProcessList[index];
                              final processName = ref.watch(
                                processNameProvider(processStat.key),
                              );
                              return ListTile(
                                leading: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: AppIconById(
                                    id: processName,
                                  ),
                                ),
                                title: Text(
                                  processName,
                                ),
                                trailing: Text(
                                  '${processStat.value.toStringAsFixed(2)}%',
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
