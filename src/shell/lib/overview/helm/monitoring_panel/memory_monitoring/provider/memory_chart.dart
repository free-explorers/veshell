import 'package:fl_chart/fl_chart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'memory_chart.g.dart';

/// Rolling window of memory usage samples, oldest first.
///
/// Kept alive and fed continuously, so the chart always shows the last
/// [_maxPoints] samples (about a minute) of memory usage.
@Riverpod(keepAlive: true)
class MemoryChart extends _$MemoryChart {
  static const _maxPoints = 120;

  @override
  List<FlSpot> build() => const [];

  /// Appends [value], dropping the oldest point past [_maxPoints].
  void add(double value) {
    final lastX = state.isEmpty ? -1 : state.last.x;
    final next = [...state, FlSpot(lastX + 1, value)];
    state = next.length > _maxPoints
        ? next.sublist(next.length - _maxPoints)
        : next;
  }
}
