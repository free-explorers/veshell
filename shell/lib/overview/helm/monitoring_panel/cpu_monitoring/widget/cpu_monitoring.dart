import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:shell/application/widget/app_icon.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/cpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/process_name.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/processes_cpu_stats.dart';

class CpuMonitoringWidget extends HookConsumerWidget {
  const CpuMonitoringWidget({
    this.isExpanded = false,
    super.key,
  });
  final bool isExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(cpuStatsStateProvider);
    return Column(
      children: [
        ListTile(
          visualDensity: VisualDensity.compact,
          onTap: () {},
          leading: IconButton(
            onPressed: () {},
            icon: Icon(
              MdiIcons.chip,
            ),
          ),
          title: SliderTheme(
            data: Theme.of(context).sliderTheme.copyWith(
                  disabledActiveTrackColor:
                      Theme.of(context).colorScheme.primary,
                  trackHeight: 10,
                  thumbShape: const RoundSliderThumbShape(
                    disabledThumbRadius: 6,
                    elevation: 0,
                  ),
                  disabledThumbColor: Theme.of(context).colorScheme.primary,
                ),
            child: Slider(
              value: stats.cpuLoad / 100,
              secondaryTrackValue: stats.loadOnMostUsedCore / 100,
              onChanged: null,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${stats.cpuLoad}%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(
                width: 24,
              ),
              Icon(MdiIcons.chevronUp),
            ],
          ),
        ),
        if (isExpanded)
          Consumer(
            builder: (context, ref, child) {
              final processesStats = ref.watch(processesCpuStatsProvider);
              final sortedProcessList = processesStats.toEntryIList().sort(
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
                        final processName =
                            ref.watch(processNameProvider(processStat.key));
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
                          trailing: Text(processStat.value.toStringAsFixed(2)),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
