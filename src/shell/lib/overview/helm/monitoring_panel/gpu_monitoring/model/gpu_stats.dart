import 'package:freezed_annotation/freezed_annotation.dart';

part 'gpu_stats.freezed.dart';

/// Telemetry of one GPU, as shown in the GPU card.
///
/// Only [load] and the VRAM pair are always present; the rest depends on what
/// the vendor exposes through `hwmon`.
@freezed
abstract class GpuStats with _$GpuStats {
  /// Creates a GPU reading. The defaults describe a card with no data yet.
  const factory GpuStats({
    @Default(0) int load,
    @Default(0) int vramUsedMb,
    @Default(0) int vramTotalMb,
    int? gttUsedMb,
    int? gttTotalMb,
    double? temperatureCelsius,
    double? powerWatts,
    int? coreClockMhz,
    int? memoryClockMhz,
  }) = _GpuStats;
}
