import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_memory_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_parsing.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/process_gpu.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/provider/machine_sampler.dart';

part 'gpu_stats.g.dart';

/// GPU telemetry, from the GPU reading of each [MachineSample].
///
/// Kept alive and primed at startup like the CPU and memory samplers, so the
/// chart describes the recent past when the overview opens. When no supported
/// GPU is present it stays at [GpuStats] defaults and never samples.
@Riverpod(keepAlive: true)
class GpuStatsState extends _$GpuStatsState {
  Map<int, Map<String, int>>? _previousClients;
  DateTime? _previousAt;

  @override
  GpuStats build() {
    final device = ref.watch(gpuDeviceProvider);
    if (device == null) return const GpuStats();
    ref.listen(machineSamplesProvider, (_, next) {
      final sample = next.value;
      if (sample != null) _sample(sample);
    });
    return const GpuStats();
  }

  void _sample(MachineSample sample) {
    final stats = sample.gpu;
    if (stats == null) return;
    // Intel's reader can only offer a frequency proxy; prefer the engine times
    // the kernel exposes in fdinfo, which the sampler walks on Intel only.
    // Other vendors already report a real busy counter, so their value is kept
    // as is.
    final engines = sample.gpuEngines;
    final load = engines == null
        ? stats.load
        : _engineLoad(engines, sample.takenAt) ?? stats.load;
    final reading = stats.copyWith(load: load);
    state = reading;
    ref.read(gpuChartProvider.notifier).add(reading.load.toDouble());
    // Integrated GPUs (Intel) have no dedicated VRAM; skip the series there.
    if (reading.vramTotalMb > 0) {
      ref.read(gpuMemoryChartProvider.notifier).add(vramUsedPercent(reading));
    }
  }

  /// Busy share of the GPU's busiest engine in [sample], since the previous
  /// one, taken at [now].
  ///
  /// The deltas are taken per client, then summed per engine: a client that
  /// exits only loses its own counters instead of subtracting its lifetime
  /// from the total, and a client absent from the previous sample is skipped
  /// rather than reported as a one-sample spike. Engines run in parallel, so
  /// the busiest engine's delta over the elapsed time is the busy share.
  ///
  /// `null` until a second sample exists, and when the clients report no
  /// `drm-engine-*` counters at all (Xe reports `drm-cycles-*`), so the caller
  /// keeps the reader's own value. Engine counters with no work read 0.
  int? _engineLoad(DeviceEngineSample sample, DateTime now) {
    final clients = sample.clientEngines;
    final previous = _previousClients;
    final previousAt = _previousAt;
    _previousClients = clients;
    _previousAt = now;
    if (previous == null || previousAt == null) return null;
    if (!sample.hasEngineCounters) return null;
    final elapsed = now.difference(previousAt).inMicroseconds * 1000;
    if (elapsed <= 0) return null;

    final totals = <String, int>{};
    clients.forEach((clientId, engines) {
      final before = previous[clientId];
      // Absent last time: its counter covers the interval only partially, so
      // reading it whole would spike the sample.
      if (before == null) return;
      engines.forEach((engine, nanoseconds) {
        final delta = nanoseconds - (before[engine] ?? 0);
        if (delta > 0) totals[engine] = (totals[engine] ?? 0) + delta;
      });
    });
    if (totals.isEmpty) return 0;
    final busiest = totals.values.reduce((a, b) => a > b ? a : b);
    return (busiest * 100 / elapsed).clamp(0, 100).round();
  }
}
