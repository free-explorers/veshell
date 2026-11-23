import 'dart:async';
import 'dart:isolate';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_stats_reader.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/process_gpu.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';
import 'package:shell/shared/util/logger.dart';

part 'machine_sampler.g.dart';

/// One whole-machine reading, taken every [monitoringSampleInterval].
///
/// Each field is `null` when its source could not be read on that tick.
class MachineSample {
  /// Creates a reading.
  const MachineSample({
    required this.takenAt,
    this.procStat,
    this.memInfo,
    this.gpu,
    this.gpuEngines,
  });

  /// When the reading was taken, for rates computed between two readings.
  final DateTime takenAt;

  /// Contents of `/proc/stat`.
  final String? procStat;

  /// Contents of `/proc/meminfo`.
  final String? memInfo;

  /// Telemetry of the monitored GPU, when there is one.
  final GpuStats? gpu;

  /// Engine times of the monitored GPU's clients, on Intel only: its reader
  /// has no busy counter, so the load is taken from these instead.
  final DeviceEngineSample? gpuEngines;
}

/// The whole-machine readings behind the CPU, memory and GPU charts.
///
/// These samplers run for the whole session, so the charts describe the
/// recent past when the overview opens. They read on a background isolate,
/// with blocking reads, and post one message per tick: the UI isolate wakes
/// once per interval instead of once per step of each asynchronous file read,
/// which kept an idle desktop's UI thread waking over a hundred times per
/// second.
@Riverpod(keepAlive: true)
Stream<MachineSample> machineSamples(Ref ref) {
  final device = ref.watch(gpuDeviceProvider);
  final port = ReceivePort('MonitoringSampler');
  var disposed = false;
  Isolate? isolate;
  ref.onDispose(() {
    disposed = true;
    isolate?.kill(priority: Isolate.immediate);
    port.close();
  });
  unawaited(
    Isolate.spawn(_runSampler, (
      port.sendPort,
      device,
    ), debugName: 'MonitoringSampler').then((spawned) {
      if (disposed) {
        spawned.kill(priority: Isolate.immediate);
      } else {
        isolate = spawned;
      }
    }),
  );
  return port.cast<MachineSample>();
}

/// The sampler isolate: one reading immediately, then one per interval.
///
/// Sampling before the first interval matters at startup: the charts are
/// primed with a first point instead of waiting a full tick. A sample is
/// synchronous, so a slow one delays the next tick rather than overlapping it.
void _runSampler((SendPort, GpuDevice?) arguments) {
  final (port, device) = arguments;
  void sample() {
    try {
      port.send(
        MachineSample(
          takenAt: DateTime.now(),
          procStat: readTextFileSync('/proc/stat'),
          memInfo: readTextFileSync('/proc/meminfo'),
          gpu: device == null ? null : readGpuStats(device),
          gpuEngines: device?.vendor == GpuVendor.intel
              ? walkDeviceClients(device!)
              : null,
        ),
      );
    } on Object catch (error, stackTrace) {
      // An uncaught error would end the isolate, and every chart with it.
      monitoringLog.warning('monitoring sample failed', error, stackTrace);
    }
  }

  sample();
  Timer.periodic(monitoringSampleInterval, (_) => sample());
}
