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

/// One whole-machine reading, taken every [monitoringSampleInterval] while a
/// chart is on screen and every [monitoringIdleSampleInterval] otherwise.
///
/// Each field is `null` when its source could not be read on that tick.
class MachineSample {
  /// Creates a reading.
  const MachineSample({
    required this.takenAt,
    this.slots = 1,
    this.procStat,
    this.memInfo,
    this.gpu,
    this.gpuEngines,
  });

  /// When the reading was taken, for rates computed between two readings.
  final DateTime takenAt;

  /// How many [monitoringSampleInterval] chart slots this reading covers.
  ///
  /// `1` at the full rate; more for a reading taken at the idle rate, which
  /// the charts repeat so their time axis stays exact.
  final int slots;

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
///
/// The isolate samples at [monitoringIdleSampleInterval] until
/// [setFullRate] asks for [monitoringSampleInterval], which
/// [monitoringOnScreenProvider] does while a chart is on screen.
@Riverpod(keepAlive: true)
class MachineSampler extends _$MachineSampler {
  SendPort? _control;
  bool _fullRate = false;

  @override
  Stream<MachineSample> build() {
    final device = ref.watch(gpuDeviceProvider);
    final port = ReceivePort('MonitoringSampler');
    final samples = StreamController<MachineSample>();
    var disposed = false;
    Isolate? isolate;
    port.listen((message) {
      switch (message) {
        case final SendPort control:
          _control = control;
          _sendRate();
        case final MachineSample sample:
          samples.add(sample);
      }
    });
    ref.onDispose(() {
      disposed = true;
      _control = null;
      isolate?.kill(priority: Isolate.immediate);
      port.close();
      unawaited(samples.close());
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
    return samples.stream;
  }

  /// Samples at [monitoringSampleInterval] when [fullRate], otherwise at
  /// [monitoringIdleSampleInterval]. Switching to the full rate takes a
  /// reading at once, so a chart that just appeared shows the present.
  void setFullRate({required bool fullRate}) {
    if (_fullRate == fullRate) return;
    _fullRate = fullRate;
    _sendRate();
  }

  void _sendRate() => _control?.send(
    _fullRate ? monitoringSampleInterval : monitoringIdleSampleInterval,
  );
}

/// Alive while a monitoring chart is on screen: the sampler runs at the full
/// rate for as long as something watches it.
///
/// The monitoring cards live in the overview, which unmounts its content when
/// it closes, so watching this from the cards is enough.
@riverpod
void monitoringOnScreen(Ref ref) {
  final sampler = ref.read(machineSamplerProvider.notifier)
    ..setFullRate(fullRate: true);
  ref.onDispose(() => sampler.setFullRate(fullRate: false));
}

/// The sampler isolate.
///
/// It reads once immediately, so the charts are primed with a first point
/// instead of waiting a full tick, then once per interval. A message from the
/// provider changes the interval; a faster one also reads at once. A sample is
/// synchronous, so a slow one delays the next tick rather than overlapping it.
void _runSampler((SendPort, GpuDevice?) arguments) {
  final (port, device) = arguments;
  var interval = monitoringIdleSampleInterval;
  DateTime? previous;
  Timer? timer;

  void sample() {
    final now = DateTime.now();
    // The slots the reading covers since the previous one, so a slow tick
    // fills the time it spanned (and a reading taken early, when the rate
    // goes up, does not count as a full idle interval).
    final slots = previous == null
        ? 1
        : (now.difference(previous!).inMicroseconds /
                  monitoringSampleInterval.inMicroseconds)
              .round()
              .clamp(1, monitoringChartBufferSamples);
    previous = now;
    try {
      port.send(
        MachineSample(
          takenAt: now,
          slots: slots,
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

  void schedule() {
    timer?.cancel();
    timer = Timer.periodic(interval, (_) => sample());
  }

  final control = ReceivePort('MonitoringSamplerControl')
    ..listen((message) {
      if (message is! Duration || message == interval) return;
      final faster = message < interval;
      interval = message;
      if (faster) sample();
      schedule();
    });
  port.send(control.sendPort);

  sample();
  schedule();
}
