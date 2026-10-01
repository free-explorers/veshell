import 'package:freezed_annotation/freezed_annotation.dart';

part 'cpu.freezed.dart';

/// Whole-machine CPU load, as shown in the CPU card badge.
@freezed
abstract class CpuStats with _$CpuStats {
  /// Creates a CPU load reading in percent (`0..100`).
  factory CpuStats({required int cpuLoad}) = _CpuStats;
}
