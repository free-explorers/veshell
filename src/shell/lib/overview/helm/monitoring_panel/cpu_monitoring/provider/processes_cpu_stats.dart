import 'dart:async';
import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/model/cpu_line.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/model/processes_cpu_stats_snapshot.dart';
import 'package:shell/overview/helm/monitoring_panel/provider/process_list.dart';

part 'processes_cpu_stats.g.dart';

@riverpod
class ProcessesCpuStats extends _$ProcessesCpuStats {
  ProcessesCpuStatsSnapshot? _prevSnapshot;
  @override
  IMap<int, double> build() {
    final timer =
        Timer.periodic(const Duration(milliseconds: 500), (Timer t) async {
      if (!ref.mounted) return;
      final snapshot = await takeSnapshot();
      if (_prevSnapshot != null) {
        state = calculateCpuStatsForEachProcesses(_prevSnapshot!, snapshot);
      }
      _prevSnapshot = snapshot;
    });
    ref.onDispose(timer.cancel);
    return <int, double>{}.lock;
  }

  Future<ProcessesCpuStatsSnapshot> takeSnapshot() async {
    final cpuStat = await File('/proc/stat').readAsLines();
    final cpu = cpuStat.first
        .split(' ')
        .where((string) => string.trim().isNotEmpty)
        .toList();
    final line = CpuLine(
      label: cpu[0],
      user: int.parse(cpu[1]),
      nice: int.parse(cpu[2]),
      system: int.parse(cpu[3]),
      idle: int.parse(cpu[4]),
      iowait: int.parse(cpu[5]),
      irq: int.parse(cpu[6]),
      softirq: int.parse(cpu[7]),
      steal: int.parse(cpu[8]),
      guest: int.parse(cpu[9]),
      guestNice: int.parse(cpu[10]),
    );

    final totalCpu = line.user +
        line.nice +
        line.system +
        line.irq +
        line.softirq +
        line.steal +
        line.idle +
        line.iowait;

    final processList = await ref.read(processListProvider.future);
    final usageMap = <int, int>{};
    for (final process in processList) {
      if (!File('/proc/$process/stat').existsSync()) continue;
      final stat = await File('/proc/$process/stat').readAsLines();
      final statLine = stat.first
          .split(' ')
          .where((string) => string.trim().isNotEmpty)
          .toList();
      final utime = int.parse(statLine[13]);
      final stime = int.parse(statLine[14]);
      final totalTime = utime + stime;
      usageMap[process] = totalTime;
    }

    return ProcessesCpuStatsSnapshot(
      totalCpu: totalCpu,
      cpuUsagePerProcess: usageMap.lock,
    );
  }

  IMap<int, double> calculateCpuStatsForEachProcesses(
    ProcessesCpuStatsSnapshot prevSnapshot,
    ProcessesCpuStatsSnapshot snapshot,
  ) {
    final cpuUsagePerProcess = <int, double>{};
    final totalCpuDiff = snapshot.totalCpu - prevSnapshot.totalCpu;
    for (final process in snapshot.cpuUsagePerProcess.keys) {
      final prevUsage = prevSnapshot.cpuUsagePerProcess[process] ?? 0;
      final usage = snapshot.cpuUsagePerProcess[process] ?? 0;
      final diff = usage - prevUsage;
      final percentage = (diff / totalCpuDiff) * 100;
      cpuUsagePerProcess[process] = percentage;
    }
    return cpuUsagePerProcess.lock;
  }
}
