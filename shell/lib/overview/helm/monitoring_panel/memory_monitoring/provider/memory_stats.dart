import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/model/memory.dart';

part 'memory_stats.g.dart';

@Riverpod(keepAlive: true)
class MemoryStatsState extends _$MemoryStatsState {
  final _memInfoFile = File('/proc/meminfo');
  Map<String, int>? _prevSnapshot;
  @override
  MemoryStats build() {
    final timer =
        Timer.periodic(const Duration(milliseconds: 500), (Timer t) async {
      final snapshot = await takeSnapshot();
      if (_prevSnapshot != null) {
        state = calculateMemoryStats(_prevSnapshot!, snapshot);
      }
      _prevSnapshot = snapshot;
    });
    ref.onDispose(timer.cancel);

    return MemoryStats(
      memoryUsage: 0,
    );
  }

  Future<Map<String, int>> takeSnapshot() async {
    final lines = await _memInfoFile.readAsLines();

    return Map.fromEntries(
      lines.map(
        (line) {
          final parts = line.split(':');
          return MapEntry(parts[0], int.parse(parts[1].trim().split(' ')[0]));
        },
      ),
    );
  }

  MemoryStats calculateMemoryStats(
    Map<String, int> prevSnapshot,
    Map<String, int> snapshot,
  ) {
    final totalMemory = snapshot['MemTotal']!;
    final freeMemory =
        snapshot['MemFree']! + snapshot['Buffers']! + snapshot['Cached']!;
    final usedMemory = totalMemory - freeMemory;
    final usage = (usedMemory / totalMemory) * 100;

    return MemoryStats(
      memoryUsage: usage.round(),
    );
  }
}
