import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/cpu_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/cpu_monitoring/provider/cpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/provider/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/provider/memory_chart.dart';
import 'package:shell/overview/helm/monitoring_panel/memory_monitoring/provider/memory_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/provider/machine_sampler.dart';

void main() {
  test('startPolling samples immediately, never overlaps, and stops', () {
    fakeAsync((async) {
      var started = 0;
      var completed = 0;
      final cancel = startPolling(const Duration(milliseconds: 500), () async {
        started++;
        await Future<void>.delayed(const Duration(milliseconds: 800));
        completed++;
      });

      // The first sample does not wait for a full interval.
      async.elapse(const Duration(milliseconds: 1));
      expect(started, 1);

      // It finishes at t=800; the next tick waits a full interval after that.
      async.elapse(const Duration(milliseconds: 799));
      expect(completed, 1);
      expect(started, 1);

      async.elapse(const Duration(milliseconds: 500)); // t=1300
      expect(started, 2);

      cancel();
      async.elapse(const Duration(seconds: 10));
      expect(started, 2);
    });
  });

  test(
    'the machine sampler posts whole-machine readings from its isolate',
    () async {
      final container = ProviderContainer(
        overrides: [gpuDeviceProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final first = Completer<MachineSample>();
      container.listen(machineSamplerProvider, (_, next) {
        final sample = next.value;
        if (sample != null && !first.isCompleted) first.complete(sample);
      });

      final sample = await first.future.timeout(const Duration(seconds: 5));
      expect(sample.gpu, isNull);
      if (!Platform.isLinux) return;
      expect(sample.procStat, startsWith('cpu '));
      expect(sample.memInfo, contains('MemTotal:'));
    },
  );

  test('the CPU and memory charts fill from the sampler', () async {
    if (!Platform.isLinux) return;
    final container = ProviderContainer(
      overrides: [gpuDeviceProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    // CPU load is a delta, so its first point needs a second reading.
    final cpu = Completer<void>();
    container
      ..listen(cpuChartProvider, (_, next) {
        if (next.isNotEmpty && !cpu.isCompleted) cpu.complete();
      })
      // Primed as main.dart does: a listened provider is never paused.
      ..listen(cpuStatsStateProvider, (_, _) {})
      ..listen(memoryStatsStateProvider, (_, _) {})
      // As if the cards were on screen: full rate, one slot per reading.
      ..listen(monitoringOnScreenProvider, (_, _) {});

    await cpu.future.timeout(const Duration(seconds: 5));
    expect(container.read(memoryChartProvider), isNotEmpty);
  });

  test('a chart repeats a reading over the slots it covers', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(cpuChartProvider.notifier)
      ..add(10)
      ..add(20, slots: 4);
    expect(container.read(cpuChartProvider).map((spot) => (spot.x, spot.y)), [
      (0.0, 10.0),
      (1.0, 20.0),
      (2.0, 20.0),
      (3.0, 20.0),
      (4.0, 20.0),
    ]);
  });

  test('the sampler reads at once when a chart comes on screen', () async {
    final container = ProviderContainer(
      overrides: [gpuDeviceProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    final samples = <MachineSample>[];
    container.listen(machineSamplerProvider, (_, next) {
      final sample = next.value;
      if (sample != null) samples.add(sample);
    });
    // The idle rate: the first reading, then nothing for two seconds.
    await _until(() => samples.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(samples, hasLength(1));

    // A chart on screen: a reading at once, then every 500 ms.
    final onScreen = container.listen(monitoringOnScreenProvider, (_, _) {});
    await _until(() => samples.length >= 3);
    expect(samples.last.slots, 1);
    onScreen.close();
  });

  test('readings stay an interval apart when the rate goes up', () async {
    // A chart on screen as the sampler starts: the full rate is asked for
    // right after the first reading. A second reading milliseconds later
    // would make the CPU load a 0 or 100 % artifact.
    final container = ProviderContainer(
      overrides: [gpuDeviceProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);
    final samples = <MachineSample>[];
    container
      ..listen(machineSamplerProvider, (_, next) {
        final sample = next.value;
        if (sample != null) samples.add(sample);
      })
      ..listen(monitoringOnScreenProvider, (_, _) {});

    await _until(() => samples.length >= 3);
    for (var i = 1; i < samples.length; i++) {
      final gap = samples[i].takenAt.difference(samples[i - 1].takenAt);
      expect(gap, greaterThan(const Duration(milliseconds: 450)));
    }
  });
}

/// Polls [condition] until it holds, failing after five seconds.
Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('condition never held');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
