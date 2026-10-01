import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/model/memory.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/provider/memory_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_parsing.dart';

part 'memory_stats.g.dart';

/// Whole-machine memory usage, sampled from `/proc/meminfo` every
/// [monitoringSampleInterval].
///
/// Kept alive and primed at startup, like the CPU sampler, so the graph always
/// describes the recent past. The per-process breakdown stays gated on the
/// expanded card.
@Riverpod(keepAlive: true)
class MemoryStatsState extends _$MemoryStatsState {
  @override
  MemoryStats build() {
    final cancel = startPolling(monitoringSampleInterval, _sample);
    ref.onDispose(cancel);
    return MemoryStats(memoryUsage: 0);
  }

  Future<void> _sample() async {
    final contents = await File('/proc/meminfo').readAsString();
    if (!ref.mounted) return;
    final usage = memoryUsedPercent(parseMemInfo(contents));
    state = MemoryStats(memoryUsage: usage);
    ref.read(memoryChartProvider.notifier).add(usage.toDouble());
  }
}
