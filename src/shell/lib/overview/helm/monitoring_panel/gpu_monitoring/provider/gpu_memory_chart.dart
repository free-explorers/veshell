import 'package:fl_chart/fl_chart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gpu_memory_chart.g.dart';

/// Rolling window of GPU VRAM usage samples, oldest first.
///
/// Kept alive and fed continuously alongside the load chart, so the GPU card
/// can overlay load and VRAM over the same recent window.
@Riverpod(keepAlive: true)
class GpuMemoryChart extends _$GpuMemoryChart {
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
