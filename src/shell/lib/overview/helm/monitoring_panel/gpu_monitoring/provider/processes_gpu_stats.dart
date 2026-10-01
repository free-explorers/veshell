import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/amdgpu.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/drm_fdinfo.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/process_gpu.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

part 'processes_gpu_stats.g.dart';

/// Per-process GPU busy share, sampled only while the GPU card is expanded.
///
/// The share is the change in the process's total engine time over the
/// interval, so a process using several engines at once can exceed 100%.
@riverpod
class ProcessesGpuStats extends _$ProcessesGpuStats {
  Map<int, int>? _previousNanoseconds;
  DateTime? _previousAt;

  @override
  IMap<int, double> build() {
    final device = ref.watch(gpuDeviceProvider);
    if (device == null) return <int, double>{}.lock;
    final cancel = startPolling(
      monitoringSampleInterval,
      () => _sample(device),
    );
    ref.onDispose(cancel);
    return <int, double>{}.lock;
  }

  Future<void> _sample(GpuDevice device) async {
    final now = DateTime.now();
    final nanoseconds = await sampleProcessEngineNanoseconds(device);
    final previous = _previousNanoseconds;
    final previousAt = _previousAt;
    _previousNanoseconds = nanoseconds;
    _previousAt = now;
    if (previous == null || previousAt == null || !ref.mounted) return;

    final elapsedNanoseconds = now.difference(previousAt).inMicroseconds * 1000;
    final shares = gpuBusyShares(previous, nanoseconds, elapsedNanoseconds);
    state = shares.lock;
  }
}
