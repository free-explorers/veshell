import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitor_panel/cpu_monitor/model/cpu.dart';
import 'package:shell/overview/helm/monitor_panel/cpu_monitor/model/cpu_line.dart';

part 'cpu_stats.g.dart';

@Riverpod(keepAlive: true)
class CpuStatsState extends _$CpuStatsState {
  final _file = File('/proc/stat');
  List<CpuLine>? _prevSnapshot;
  @override
  CpuStats build() {
    Timer.periodic(const Duration(milliseconds: 500), (Timer t) async {
      final snapshot = await takeSnapshot();
      if (_prevSnapshot != null) {
        state = calculateCpuStats(_prevSnapshot!, snapshot);
      }
      _prevSnapshot = snapshot;
    });
    return CpuStats(
      cpuLoad: 0,
      loadOnMostUsedCore: 0,
    );
  }

  Future<List<CpuLine>> takeSnapshot() async {
    final lines = await _file.readAsLines();

    return lines.where((line) => line.startsWith('cpu')).map((line) {
      final strings =
          line.split(' ').where((string) => string.trim().isNotEmpty).toList();
      return CpuLine(
        label: strings[0],
        user: int.parse(strings[1]),
        nice: int.parse(strings[2]),
        system: int.parse(strings[3]),
        idle: int.parse(strings[4]),
        iowait: int.parse(strings[5]),
        irq: int.parse(strings[6]),
        softirq: int.parse(strings[7]),
        steal: int.parse(strings[8]),
        guest: int.parse(strings[9]),
        guestNice: int.parse(strings[10]),
      );
    }).toList();
  }

  CpuStats calculateCpuStats(
    List<CpuLine> prevSnapshot,
    List<CpuLine> snapshot,
  ) {
    final globalUsage =
        _getUsagePercentForLine(snapshot.first, prevSnapshot.first);
    final cores = snapshot
        .skip(1)
        .map(
          (line) => _getUsagePercentForLine(
            line,
            prevSnapshot[snapshot.indexOf(line)],
          ),
        )
        .toList();
    final mostUsages =
        cores.reduce((value, element) => value > element ? value : element);

    return CpuStats(
      cpuLoad: globalUsage.round(),
      loadOnMostUsedCore: mostUsages.round(),
    );
  }

  double _getUsagePercentForLine(CpuLine line, CpuLine prevLine) {
    final prevIdle = prevLine.idle + prevLine.iowait;
    final idle = line.idle + line.iowait;
    final prevNonIdle = prevLine.user +
        prevLine.nice +
        prevLine.system +
        prevLine.irq +
        prevLine.softirq +
        prevLine.steal;
    final nonIdle = line.user +
        line.nice +
        line.system +
        line.irq +
        line.softirq +
        line.steal;
    final prevTotal = prevIdle + prevNonIdle;
    final total = idle + nonIdle;
    final totalD = total - prevTotal;
    final idleD = idle - prevIdle;
    final usage = (totalD - idleD) / totalD;
    return usage * 100;
  }
}
