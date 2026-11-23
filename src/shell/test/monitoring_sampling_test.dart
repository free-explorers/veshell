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
      container.listen(machineSamplesProvider, (_, next) {
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
      ..listen(memoryStatsStateProvider, (_, _) {});

    await cpu.future.timeout(const Duration(seconds: 5));
    expect(container.read(memoryChartProvider), isNotEmpty);
  });
}
