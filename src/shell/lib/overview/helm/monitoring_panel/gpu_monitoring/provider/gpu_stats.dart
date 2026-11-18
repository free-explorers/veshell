import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_memory_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_parsing.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_stats_reader.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/process_gpu.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

part 'gpu_stats.g.dart';

/// GPU telemetry, sampled from the amdgpu sysfs every
/// [monitoringSampleInterval].
///
/// Kept alive and primed at startup like the CPU and memory samplers, so the
/// chart describes the recent past when the overview opens. When no supported
/// GPU is present it stays at [GpuStats] defaults and never samples.
@Riverpod(keepAlive: true)
class GpuStatsState extends _$GpuStatsState {
  Map<String, int>? _previousEngineNanoseconds;
  DateTime? _previousAt;

  @override
  GpuStats build() {
    final device = ref.watch(gpuDeviceProvider);
    if (device == null) return const GpuStats();
    final cancel = startPolling(
      monitoringSampleInterval,
      () => _sample(device),
    );
    ref.onDispose(cancel);
    return const GpuStats();
  }

  Future<void> _sample(GpuDevice device) async {
    final stats = await readGpuStats(device);
    if (!ref.mounted || stats == null) return;
    // Intel's reader can only offer a frequency proxy; prefer the engine times
    // the kernel exposes in fdinfo. Other vendors already report a real busy
    // counter, so their value is kept as is.
    final load = device.vendor == GpuVendor.intel
        ? await _engineLoad(device) ?? stats.load
        : stats.load;
    final reading = stats.copyWith(load: load);
    state = reading;
    ref.read(gpuChartProvider.notifier).add(reading.load.toDouble());
    // Integrated GPUs (Intel) have no dedicated VRAM; skip the series there.
    if (reading.vramTotalMb > 0) {
      ref.read(gpuMemoryChartProvider.notifier).add(vramUsedPercent(reading));
    }
  }

  /// Busy share of [device]'s busiest engine since the previous sample.
  ///
  /// The kernels sum engine time per client, and engines run in parallel, so
  /// the busiest engine's delta over the elapsed time is the GPU's busy share.
  /// `null` until a second sample exists.
  Future<int?> _engineLoad(GpuDevice device) async {
    final now = DateTime.now();
    final engines = await sampleEngineNanoseconds(device);
    final previous = _previousEngineNanoseconds;
    final previousAt = _previousAt;
    _previousEngineNanoseconds = engines;
    _previousAt = now;
    if (previous == null || previousAt == null || !ref.mounted) return null;
    final elapsed = now.difference(previousAt).inMicroseconds * 1000;
    if (elapsed <= 0) return null;

    var busiest = 0;
    engines.forEach((engine, nanoseconds) {
      final delta = nanoseconds - (previous[engine] ?? 0);
      if (delta > busiest) busiest = delta;
    });
    return (busiest * 100 / elapsed).clamp(0, 100).round();
  }
}
