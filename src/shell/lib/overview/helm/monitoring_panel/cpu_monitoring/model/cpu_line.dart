import 'package:freezed_annotation/freezed_annotation.dart';

part 'cpu_line.freezed.dart';

@freezed
class CpuLine with _$CpuLine {
  factory CpuLine({
    required String label,
    required int user,
    required int nice,
    required int system,
    required int idle,
    required int iowait,
    required int irq,
    required int softirq,
    required int steal,
    required int guest,
    required int guestNice,
  }) = _CpuLine;
}
