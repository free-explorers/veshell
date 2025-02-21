import 'package:fl_chart/fl_chart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/provider/memory_stats.dart';

part 'memory_chart.g.dart';

@Riverpod(keepAlive: true)
class MemoryChart extends _$MemoryChart {
  @override
  List<FlSpot> build() {
    ref.listen(memoryStatsStateProvider, (previous, next) {
      state = [
        ...state,
        FlSpot(
          state.lastOrNull != null ? state.last.x + 1 : 0,
          next.memoryUsage.toDouble(),
        ),
      ].sublist(state.length > 49 ? state.length - 49 : 0);
    });
    return [];
  }
}
