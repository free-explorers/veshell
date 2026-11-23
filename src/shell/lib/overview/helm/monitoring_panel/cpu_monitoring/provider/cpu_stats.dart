import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/model/cpu.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/cpu_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_parsing.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/provider/machine_sampler.dart';

part 'cpu_stats.g.dart';

/// Whole-machine CPU load, from the `/proc/stat` of each [MachineSample].
///
/// Kept alive and primed at startup so the graph always describes the recent
/// past: opening the overview must show what happened just before, not an empty
/// or stale chart. It reads a single small file per tick, on the sampler's
/// isolate, unlike the per-process sampler, which stays gated on the expanded
/// card.
@Riverpod(keepAlive: true)
class CpuStatsState extends _$CpuStatsState {
  CpuLine? _previous;

  @override
  CpuStats build() {
    ref.listen(machineSamplesProvider, (_, next) {
      final contents = next.value?.procStat;
      if (contents != null) _sample(contents);
    });
    return CpuStats(cpuLoad: 0);
  }

  void _sample(String contents) {
    final lines = parseProcStat(contents);
    if (lines.isEmpty) return;
    final now = lines.first;
    final previous = _previous;
    _previous = now;
    if (previous == null) return;
    final usage = cpuUsagePercent(previous, now);
    state = CpuStats(cpuLoad: usage.round());
    ref.read(cpuChartProvider.notifier).add(usage);
  }
}
