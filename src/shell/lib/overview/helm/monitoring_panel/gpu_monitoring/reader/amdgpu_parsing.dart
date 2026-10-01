import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';

/// Raw amdgpu sysfs values, in the kernel's own units.
///
/// Kept separate from the reader so [buildGpuStats] can be unit tested without
/// touching `/sys`.
class GpuRawValues {
  /// Creates a raw sample; any field the card does not expose stays `null`.
  const GpuRawValues({
    this.busyPercent,
    this.vramUsedBytes,
    this.vramTotalBytes,
    this.gttUsedBytes,
    this.gttTotalBytes,
    this.temperatureMilliCelsius,
    this.powerMicrowatts,
    this.coreClockHertz,
    this.memoryClockHertz,
  });

  /// `gpu_busy_percent`, already `0..100`.
  final int? busyPercent;

  /// `mem_info_vram_used`, in bytes.
  final int? vramUsedBytes;

  /// `mem_info_vram_total`, in bytes.
  final int? vramTotalBytes;

  /// `mem_info_gtt_used`, in bytes.
  final int? gttUsedBytes;

  /// `mem_info_gtt_total`, in bytes.
  final int? gttTotalBytes;

  /// `temp1_input`, in millidegrees Celsius.
  final int? temperatureMilliCelsius;

  /// `power1_input`, in microwatts.
  final int? powerMicrowatts;

  /// `freq1_input` (sclk), in hertz.
  final int? coreClockHertz;

  /// `freq2_input` (mclk), in hertz.
  final int? memoryClockHertz;
}

const int _bytesPerMegabyte = 1024 * 1024;

/// Assembles [GpuStats] from raw sysfs values.
///
/// Returns `null` when the card is not usable: without a busy counter or a
/// VRAM size there is nothing meaningful to show.
GpuStats? buildGpuStats(GpuRawValues raw) {
  final busy = raw.busyPercent;
  final vramUsed = raw.vramUsedBytes;
  final vramTotal = raw.vramTotalBytes;
  if (busy == null || vramUsed == null || vramTotal == null) return null;
  return GpuStats(
    load: busy.clamp(0, 100),
    vramUsedMb: vramUsed ~/ _bytesPerMegabyte,
    vramTotalMb: vramTotal ~/ _bytesPerMegabyte,
    gttUsedMb: _megabytes(raw.gttUsedBytes),
    gttTotalMb: _megabytes(raw.gttTotalBytes),
    temperatureCelsius: _celsius(raw.temperatureMilliCelsius),
    powerWatts: _watts(raw.powerMicrowatts),
    coreClockMhz: _megahertz(raw.coreClockHertz),
    memoryClockMhz: _megahertz(raw.memoryClockHertz),
  );
}

/// VRAM usage as a whole percentage, clamped to `0..100`.
double vramUsedPercent(GpuStats stats) {
  if (stats.vramTotalMb <= 0) return 0;
  return (stats.vramUsedMb / stats.vramTotalMb * 100).clamp(0, 100);
}

int? _megabytes(int? bytes) =>
    bytes == null ? null : bytes ~/ _bytesPerMegabyte;

double? _celsius(int? millidegrees) =>
    millidegrees == null ? null : millidegrees / 1000;

double? _watts(int? microwatts) =>
    microwatts == null ? null : microwatts / 1000000;

int? _megahertz(int? hertz) => hertz == null ? null : hertz ~/ 1000000;
