import 'package:freezed_annotation/freezed_annotation.dart';

part 'process_stat.freezed.dart';

@freezed
abstract class ProcessStat with _$ProcessStat {
  factory ProcessStat({
    required int pid,
    required String name,
    required int cpuUsage,
    required int memoryUsage,
    required int networkUsage,
  }) = _ProcessStat;
}
