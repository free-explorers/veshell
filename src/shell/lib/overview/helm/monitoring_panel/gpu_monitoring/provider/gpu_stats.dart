import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/amdgpu.dart';
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
    state = stats;
    ref.read(gpuChartProvider.notifier).add(stats.load.toDouble());
  }
}
