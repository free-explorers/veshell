import 'package:freezed_annotation/freezed_annotation.dart';

part 'cpu.freezed.dart';

@freezed
class CpuStats with _$CpuStats {
  factory CpuStats({
    required int cpuLoad,
    required int loadOnMostUsedCore,
  }) = _CpuStats;
}
