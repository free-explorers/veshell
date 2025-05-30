import 'package:freezed_annotation/freezed_annotation.dart';

part 'memory.freezed.dart';

@freezed
abstract class MemoryStats with _$MemoryStats {
  factory MemoryStats({
    required int memoryUsage,
  }) = _MemoryStats;
}
