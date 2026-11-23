import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/drm_fdinfo.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/process_gpu.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/provider/machine_sampler.dart';

part 'processes_gpu_stats.g.dart';

/// Per-process GPU busy share, sampled only while the GPU card is expanded.
///
/// The share is the change in the process's total engine time over the
/// interval, so a process using several engines at once can exceed 100%.
///
/// On Intel the monitoring sampler already walks the GPU clients every tick
/// for the card's load, so the list reuses that walk instead of starting its
/// own; other vendors walk `/proc` here, on the same interval.
@riverpod
class ProcessesGpuStats extends _$ProcessesGpuStats {
  Map<int, int>? _previousNanoseconds;
  DateTime? _previousAt;

  @override
  IMap<int, double> build() {
    final device = ref.watch(gpuDeviceProvider);
    if (device == null) return <int, double>{}.lock;
    if (device.vendor == GpuVendor.intel) {
      ref.listen(machineSamplerProvider, (_, next) {
        final sample = next.value;
        final engines = sample?.gpuEngines;
        if (engines != null) {
          _update(engines.processNanoseconds, sample!.takenAt);
        }
      });
    } else {
      final cancel = startPolling(monitoringSampleInterval, () async {
        final now = DateTime.now();
        final sample = await sampleDevice(device);
        if (ref.mounted) _update(sample.processNanoseconds, now);
      });
      ref.onDispose(cancel);
    }
    return <int, double>{}.lock;
  }

  void _update(Map<int, int> nanoseconds, DateTime now) {
    final previous = _previousNanoseconds;
    final previousAt = _previousAt;
    _previousNanoseconds = nanoseconds;
    _previousAt = now;
    if (previous == null || previousAt == null) return;

    final elapsedNanoseconds = now.difference(previousAt).inMicroseconds * 1000;
    final shares = gpuBusyShares(previous, nanoseconds, elapsedNanoseconds);
    state = shares.lock;
  }
}
