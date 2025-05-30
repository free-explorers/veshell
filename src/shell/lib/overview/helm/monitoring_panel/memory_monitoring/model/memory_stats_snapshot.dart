import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'memory_stats_snapshot.freezed.dart';

@freezed
abstract class MemoryStatsSnapshot with _$MemoryStatsSnapshot {
  factory MemoryStatsSnapshot({
    required int totalMem,
    required int freeMem,
    required IMap<int, int> memoryUsagePerProcess,
  }) = _MemoryStatsSnapshot;
}
