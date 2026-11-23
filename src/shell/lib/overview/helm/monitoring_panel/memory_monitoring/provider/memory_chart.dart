import 'package:fl_chart/fl_chart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';

part 'memory_chart.g.dart';

/// Rolling window of memory usage samples, oldest first.
///
/// Kept alive and fed continuously, so the chart always shows the last
/// [_maxPoints] samples (about a minute) of memory usage.
@Riverpod(keepAlive: true)
class MemoryChart extends _$MemoryChart {
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
