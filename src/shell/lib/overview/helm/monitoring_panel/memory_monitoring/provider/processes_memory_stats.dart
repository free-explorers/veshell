import 'dart:async';
import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/model/memory_stats_snapshot.dart';
import 'package:shell/overview/helm/monitoring_panel/provider/process_list.dart';

part 'processes_memory_stats.g.dart';

@riverpod
class ProcessesMemoryStats extends _$ProcessesMemoryStats {
  MemoryStatsSnapshot? _prevSnapshot;
  @override
  IMap<int, double> build() {
    final timer =
        Timer.periodic(const Duration(milliseconds: 500), (Timer t) async {
      if (!ref.mounted) return;
      final snapshot = await takeSnapshot();
      if (_prevSnapshot != null) {
        state = calculateMemoryStatsForEachProcesses(snapshot);
      }
      _prevSnapshot = snapshot;
    });
    ref.onDispose(timer.cancel);
    return <int, double>{}.lock;
  }

  Future<MemoryStatsSnapshot> takeSnapshot() async {
    final lines = await File('/proc/meminfo').readAsLines();
    final snapshot = Map.fromEntries(
      lines.map(
        (line) {
          final parts = line.split(':');
          return MapEntry(parts[0], int.parse(parts[1].trim().split(' ')[0]));
        },
      ),
    );

    final totalMem = snapshot['MemTotal']!;
    final freeMem = snapshot['MemFree']!;
    final processList = await ref.read(processListProvider.future);
    final usageMap = <int, int>{};
    final pageSize = int.parse(
      (Process.runSync('getconf', ['PAGESIZE']).stdout as String).trim(),
    );

    for (final process in processList) {
      if (!File('/proc/$process/statm').existsSync()) continue;
      final statm = await File('/proc/$process/statm').readAsLines();
      final statmLine = statm.first
          .split(' ')
          .where((string) => string.trim().isNotEmpty)
          .toList();
      final rss = int.parse(statmLine[1]) * pageSize;
      usageMap[process] = rss;
    }

    return MemoryStatsSnapshot(
      totalMem: totalMem,
      freeMem: freeMem,
      memoryUsagePerProcess: usageMap.lock,
    );
  }

  IMap<int, double> calculateMemoryStatsForEachProcesses(
    MemoryStatsSnapshot snapshot,
  ) {
    final memoryUsagePerProcess = <int, double>{};
    final totalMemInBytes = snapshot.totalMem * 1024;

    for (final process in snapshot.memoryUsagePerProcess.keys) {
      final usage = snapshot.memoryUsagePerProcess[process] ?? 0;

      //print('$usage ${snapshot.totalMem}');
      final percentage = (usage / totalMemInBytes) * 100;
      memoryUsagePerProcess[process] = percentage;
    }
    return memoryUsagePerProcess.lock;
  }
}
