import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';
import 'package:shell/overview/helm/monitoring_panel/widget/monitoring_card.dart';

Widget _chart(List<FlSpot> spots) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          height: 64,
          child: MonitoringChart(
            series: [
              MonitoringSeries(spots: spots, color: Colors.blue, filled: true),
            ],
          ),
        ),
      ),
    ),
  );
}

List<FlSpot> _window(int first, {int? count}) => [
  for (var i = first; i < first + (count ?? monitoringChartBufferSamples); i++)
    FlSpot(i.toDouble(), 50),
];

void main() {
  testWidgets('scrolls the chart window when a sample arrives', (tester) async {
    await tester.pumpWidget(_chart(_window(0)));
    await tester.pump();

    var chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, monitoringChartOverflowSamples);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_chart(_window(1)));
    await tester.pump(const Duration(milliseconds: 250));

    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, closeTo(monitoringChartOverflowSamples + 0.5, 0.1));

    await tester.pump(const Duration(milliseconds: 300));

    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, closeTo(monitoringChartOverflowSamples + 1, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('slides into the overflow window when the buffer fills', (
    tester,
  ) async {
    await tester.pumpWidget(_chart(_window(0, count: 123)));
    await tester.pump();

    var chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, 3);

    await tester.pumpWidget(_chart(_window(0)));
    await tester.pump(const Duration(milliseconds: 250));

    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, closeTo(2.5, 0.1));

    await tester.pump(const Duration(milliseconds: 300));

    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, closeTo(2, 0.01));
  });

  testWidgets('slides new samples in while the buffer is filling', (
    tester,
  ) async {
    await tester.pumpWidget(_chart(_window(0, count: 10)));
    await tester.pump();

    var chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, 9 - (monitoringWindowSamples - 1));

    await tester.pumpWidget(_chart(_window(0, count: 11)));
    await tester.pump(const Duration(milliseconds: 250));

    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, closeTo(10 - monitoringWindowSamples + 0.5, 0.1));

    await tester.pump(const Duration(milliseconds: 300));

    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, closeTo(10 - monitoringWindowSamples + 1, 0.01));
  });

  testWidgets('anchors the growing chart to the right', (tester) async {
    final spots = [for (var i = 0; i < 10; i++) FlSpot(i.toDouble(), 50)];
    await tester.pumpWidget(_chart(spots));

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.maxX, spots.last.x);
    expect(chart.data.minX, spots.last.x - (monitoringWindowSamples - 1));
  });
}
