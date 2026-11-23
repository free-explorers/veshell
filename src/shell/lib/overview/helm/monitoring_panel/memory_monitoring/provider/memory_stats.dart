import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/model/memory.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/provider/memory_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_parsing.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/provider/machine_sampler.dart';

part 'memory_stats.g.dart';

/// Whole-machine memory usage, from the `/proc/meminfo` of each
/// [MachineSample].
///
/// Kept alive and primed at startup, like the CPU sampler, so the graph always
/// describes the recent past. The per-process breakdown stays gated on the
/// expanded card.
@Riverpod(keepAlive: true)
class MemoryStatsState extends _$MemoryStatsState {
  @override
  MemoryStats build() {
    ref.listen(machineSamplerProvider, (_, next) {
      final sample = next.value;
      final contents = sample?.memInfo;
      if (contents != null) _sample(contents, sample!.slots);
    });
    return MemoryStats(memoryUsage: 0);
  }

  void _sample(String contents, int slots) {
    final usage = memoryUsedPercent(parseMemInfo(contents));
    state = MemoryStats(memoryUsage: usage);
    ref.read(memoryChartProvider.notifier).add(usage.toDouble(), slots: slots);
  }
}
