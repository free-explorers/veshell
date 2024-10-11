import 'package:fl_chart/fl_chart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/cpu_stats.dart';

part 'cpu_chart.g.dart';

@Riverpod(keepAlive: true)
class CpuChart extends _$CpuChart {
  @override
  List<FlSpot> build() {
    ref.listen(cpuStatsStateProvider, (previous, next) {
      state = [
        ...state,
        FlSpot(
          state.lastOrNull != null ? state.last.x + 1 : 0,
          next.cpuLoad.toDouble(),
        ),
      ].sublist(state.length > 49 ? state.length - 49 : 0);
    });
    return [];
  }
}
