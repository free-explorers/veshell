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
  Map<int, Map<String, int>>? _previousClients;
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
  /// The deltas are taken per client, then summed per engine: a client that
  /// exits only loses its own counters instead of subtracting its lifetime
  /// from the total. Engines run in parallel, so the busiest engine's delta
  /// over the elapsed time is the GPU's busy share.
  ///
  /// `null` until a second sample exists, and whenever the clients report no
  /// engine counters (Xe reports `drm-cycles-*` instead of `drm-engine-*`), so
  /// the caller keeps the reader's own value.
  Future<int?> _engineLoad(GpuDevice device) async {
    final now = DateTime.now();
    final clients = await sampleClientEngineNanoseconds(device);
    final previous = _previousClients;
    final previousAt = _previousAt;
    _previousClients = clients;
    _previousAt = now;
    if (previous == null || previousAt == null || !ref.mounted) return null;
    final elapsed = now.difference(previousAt).inMicroseconds * 1000;
    if (elapsed <= 0) return null;

    final totals = <String, int>{};
    clients.forEach((clientId, engines) {
      final before = previous[clientId];
      engines.forEach((engine, nanoseconds) {
        // A client seen for the first time starts at zero: its whole counter
        // is the work done since it opened.
        final delta = nanoseconds - (before?[engine] ?? 0);
        if (delta > 0) totals[engine] = (totals[engine] ?? 0) + delta;
      });
    });
    if (totals.isEmpty) return null;
    final busiest = totals.values.reduce((a, b) => a > b ? a : b);
    return (busiest * 100 / elapsed).clamp(0, 100).round();
  }
}
