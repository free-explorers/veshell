import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/cpu_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_memory_chart.dart';

void main() {
  test('CpuChart keeps the newest points in order', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final chart = container.read(cpuChartProvider.notifier);
    for (var i = 0; i < 150; i++) {
      chart.add(i.toDouble());
    }

    final spots = container.read(cpuChartProvider);

    expect(spots, hasLength(120));
    expect(spots.first.y, 30);
    expect(spots.last.y, 149);
    // The x axis keeps advancing one sample at a time.
    expect(spots.last.x - spots.first.x, 119);
  });

  test('GpuMemoryChart keeps the newest points in order', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final chart = container.read(gpuMemoryChartProvider.notifier);
    for (var i = 0; i < 10; i++) {
      chart.add(i.toDouble());
    }

    final spots = container.read(gpuMemoryChartProvider);

    expect(spots, hasLength(10));
    expect(spots.first.y, 0);
    expect(spots.last.y, 9);
  });
}
