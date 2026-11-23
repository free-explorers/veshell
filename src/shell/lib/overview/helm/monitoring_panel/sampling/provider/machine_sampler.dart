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
        case _SampleFailure(:final error, :final stackTrace):
          monitoringLog.warning(
            'monitoring sample failed',
            error,
            StackTrace.fromString(stackTrace),
          );
      }
    });
    // The isolate's own logger has no listener, and a dead sampler would only
    // show as frozen charts: report both here.
    final lifecycle = ReceivePort('MonitoringSamplerLifecycle')
      ..listen((message) {
        if (message case [final Object? error, final Object? stackTrace]) {
          monitoringLog.severe(
            'monitoring sampler failed',
            error,
            StackTrace.fromString('$stackTrace'),
          );
        } else if (!disposed) {
          monitoringLog.severe('monitoring sampler exited; charts stopped');
        }
      });
    ref.onDispose(() {
      disposed = true;
      _control = null;
      isolate?.kill(priority: Isolate.immediate);
      port.close();
      lifecycle.close();
      unawaited(samples.close());
    });
    unawaited(
      Isolate.spawn(
            _runSampler,
            (port.sendPort, device),
            debugName: 'MonitoringSampler',
            onError: lifecycle.sendPort,
            onExit: lifecycle.sendPort,
          )
          .then((spawned) {
            if (disposed) {
              spawned.kill(priority: Isolate.immediate);
            } else {
              isolate = spawned;
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            monitoringLog.severe(
              'monitoring sampler did not start',
              error,
              stackTrace,
            );
          }),
    );
    return samples.stream;
  }

  /// Samples at [monitoringSampleInterval] when [fullRate], otherwise at
  /// [monitoringIdleSampleInterval]. Switching to the full rate takes a
  /// reading at once when the last one is at least [monitoringSampleInterval]
  /// old, so a chart that just appeared shows the present.
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

/// A reading that threw, reported to the UI isolate for logging: the
/// sampler isolate's logger has no listener.
class _SampleFailure {
  const _SampleFailure(this.error, this.stackTrace);

  final String error;
  final String stackTrace;
}

/// The sampler isolate.
///
/// It reads once immediately, so the charts are primed with a first point
/// instead of waiting a full tick. Each next reading is due one interval after
/// the previous one, and a message from the provider changes the interval:
/// going to the full rate reads at once only when the previous reading is at
/// least that old. Two readings closer than that would give rates computed
/// over a few milliseconds (the CPU load counts 10 ms ticks), a 0 or 100 %
/// point on the chart. A sample is synchronous, so a slow one delays the next
/// rather than overlapping it.
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
      port.send(_SampleFailure('$error', '$stackTrace'));
    }
  }

  void schedule() {
    timer?.cancel();
    final last = previous;
    final due = last == null
        ? Duration.zero
        : interval - DateTime.now().difference(last);
    timer = Timer(due.isNegative ? Duration.zero : due, () {
      sample();
      schedule();
    });
  }

  final control = ReceivePort('MonitoringSamplerControl')
    ..listen((message) {
      if (message is! Duration || message == interval) return;
      interval = message;
      schedule();
    });
  port.send(control.sendPort);

  sample();
  schedule();
}
