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

List<FlSpot> _window(int first) => [
  for (var i = first; i < first + monitoringWindowSamples; i++)
    FlSpot(i.toDouble(), 50),
];

void main() {
  testWidgets('scrolls the chart window when a sample arrives', (tester) async {
    await tester.pumpWidget(_chart(_window(0)));
    await tester.pump();

    var chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, 0);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_chart(_window(1)));
    await tester.pump(const Duration(milliseconds: 250));

    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, closeTo(0.5, 0.1));

    await tester.pump(const Duration(milliseconds: 300));

    chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, closeTo(1, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a fixed window before the buffer is full', (tester) async {
    final spots = [for (var i = 0; i < 10; i++) FlSpot(i.toDouble(), 50)];
    await tester.pumpWidget(_chart(spots));

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.minX, 0);
    expect(chart.data.maxX, monitoringWindowSamples - 1);
  });
}
