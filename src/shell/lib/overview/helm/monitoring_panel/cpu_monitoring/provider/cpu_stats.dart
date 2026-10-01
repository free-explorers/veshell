import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/model/cpu.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/cpu_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_parsing.dart';

part 'cpu_stats.g.dart';

/// Whole-machine CPU load, sampled from `/proc/stat` every
/// [monitoringSampleInterval].
///
/// Kept alive and primed at startup so the graph always describes the recent
/// past: opening the overview must show what happened just before, not an empty
/// or stale chart. It reads a single small file per tick, unlike the
/// per-process sampler, which stays gated on the expanded card.
@Riverpod(keepAlive: true)
class CpuStatsState extends _$CpuStatsState {
  CpuLine? _previous;

  @override
  CpuStats build() {
    final cancel = startPolling(monitoringSampleInterval, _sample);
    ref.onDispose(cancel);
    return CpuStats(cpuLoad: 0);
  }

  Future<void> _sample() async {
    final contents = await File('/proc/stat').readAsString();
    if (!ref.mounted) return;
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
