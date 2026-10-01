import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/model/processes_cpu_stats_snapshot.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_parsing.dart';

part 'processes_cpu_stats.g.dart';

/// Per-process share of total CPU, sampled only while the CPU card is expanded.
@riverpod
class ProcessesCpuStats extends _$ProcessesCpuStats {
  ProcessesCpuStatsSnapshot? _previous;

  @override
  IMap<int, double> build() {
    final cancel = startPolling(monitoringSampleInterval, _sample);
    ref.onDispose(cancel);
    return <int, double>{}.lock;
  }

  Future<void> _sample() async {
    final stat = await readProcFile('/proc/stat');
    if (!ref.mounted || stat == null) return;
    final cpus = parseProcStat(stat);
    if (cpus.isEmpty) return;

    final pids = await listProcessIds();
    if (!ref.mounted) return;
    final usage = <int, int>{};
    for (final pid in pids) {
      final contents = await readProcFile('/proc/$pid/stat');
      if (contents == null) continue;
      final times = parseProcPidStat(contents);
      if (times == null) continue;
      usage[pid] = times.utime + times.stime;
    }

    final snapshot = ProcessesCpuStatsSnapshot(
      totalCpu: cpus.first.total,
      cpuUsagePerProcess: usage.lock,
    );
    final previous = _previous;
    _previous = snapshot;
    if (previous == null || !ref.mounted) return;

    final totalDiff = snapshot.totalCpu - previous.totalCpu;
    if (totalDiff <= 0) return;

    final percentages = <int, double>{};
    for (final entry in snapshot.cpuUsagePerProcess.entries) {
      final before = previous.cpuUsagePerProcess[entry.key] ?? 0;
      final delta = entry.value - before;
      if (delta <= 0) continue;
      percentages[entry.key] = delta / totalDiff * 100;
    }
    state = percentages.lock;
  }
}
