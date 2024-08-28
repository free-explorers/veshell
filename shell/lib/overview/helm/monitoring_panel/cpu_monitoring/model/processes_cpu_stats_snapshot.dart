import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'processes_cpu_stats_snapshot.freezed.dart';

@freezed
class ProcessesCpuStatsSnapshot with _$ProcessesCpuStatsSnapshot {
  factory ProcessesCpuStatsSnapshot({
    required int totalCpu,
    required IMap<int, int> cpuUsagePerProcess,
  }) = _ProcessesCpuStatsSnapshot;
}
