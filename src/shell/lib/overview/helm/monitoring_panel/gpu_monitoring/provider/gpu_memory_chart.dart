import 'package:fl_chart/fl_chart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

part 'gpu_memory_chart.g.dart';

/// Rolling window of GPU VRAM usage samples, oldest first.
///
/// Kept alive and fed continuously alongside the load chart, so the GPU card
/// can overlay load and VRAM over the same recent window.
@Riverpod(keepAlive: true)
class GpuMemoryChart extends _$GpuMemoryChart {
  static const int _maxPoints = monitoringChartBufferSamples;

  @override
  List<FlSpot> build() => const [];

  /// Appends [value] for [slots] sample slots, dropping the oldest points past
  /// [_maxPoints].
  ///
  /// A reading taken while the overview is closed covers several slots (see
  /// `MachineSample.slots`); repeating it keeps the chart's time axis exact.
  void add(double value, {int slots = 1}) {
    final lastX = state.isEmpty ? -1.0 : state.last.x;
    final next = [
      ...state,
      for (var slot = 1; slot <= slots; slot++) FlSpot(lastX + slot, value),
    ];
    state = next.length > _maxPoints
        ? next.sublist(next.length - _maxPoints)
        : next;
  }
}
