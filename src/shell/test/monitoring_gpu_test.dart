import 'package:flutter_test/flutter_test.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/amdgpu.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/amdgpu_parsing.dart';

void main() {
  group('buildGpuStats', () {
    test('converts the kernel units into display values', () {
      final stats = buildGpuStats(
        const GpuRawValues(
          busyPercent: 42,
          vramUsedBytes: 1073741824, // 1 GiB
          vramTotalBytes: 8589934592, // 8 GiB
          gttUsedBytes: 536870912, // 512 MiB
          gttTotalBytes: 17179869184, // 16 GiB
          temperatureMilliCelsius: 50000,
          powerMicrowatts: 34000000,
          coreClockHertz: 987000000,
          memoryClockHertz: 800000000,
        ),
      );

      expect(stats, isNotNull);
      expect(stats!.load, 42);
      expect(stats.vramUsedMb, 1024);
      expect(stats.vramTotalMb, 8192);
      expect(stats.gttUsedMb, 512);
      expect(stats.gttTotalMb, 16384);
      expect(stats.temperatureCelsius, 50.0);
      expect(stats.powerWatts, 34.0);
      expect(stats.coreClockMhz, 987);
      expect(stats.memoryClockMhz, 800);
    });

    test('leaves the optional fields null when hwmon exposes nothing', () {
      final stats = buildGpuStats(
        const GpuRawValues(
          busyPercent: 10,
          vramUsedBytes: 1048576,
          vramTotalBytes: 2097152,
        ),
      );

      expect(stats, isNotNull);
      expect(stats!.vramUsedMb, 1);
      expect(stats.vramTotalMb, 2);
      expect(stats.gttUsedMb, isNull);
      expect(stats.gttTotalMb, isNull);
      expect(stats.temperatureCelsius, isNull);
      expect(stats.powerWatts, isNull);
      expect(stats.coreClockMhz, isNull);
      expect(stats.memoryClockMhz, isNull);
    });

    test('returns null without a busy counter or a VRAM size', () {
      expect(
        buildGpuStats(
          const GpuRawValues(vramUsedBytes: 1, vramTotalBytes: 2),
        ),
        isNull,
      );
      expect(buildGpuStats(const GpuRawValues(busyPercent: 1)), isNull);
    });

    test('clamps the busy percentage to 0..100', () {
      GpuStats? build(int busy) => buildGpuStats(
        GpuRawValues(busyPercent: busy, vramUsedBytes: 0, vramTotalBytes: 0),
      );

      expect(build(150)!.load, 100);
      expect(build(-5)!.load, 0);
    });
  });

  test('reads a live amdgpu sysfs when one is present', () async {
    final device = detectGpuDevice();
    // No supported GPU (or not Linux): there is nothing to assert.
    if (device == null) return;

    final stats = await readGpuStats(device);

    expect(stats, isNotNull);
    expect(stats!.load, inInclusiveRange(0, 100));
    expect(stats.vramTotalMb, greaterThan(0));
    expect(stats.vramUsedMb, lessThanOrEqualTo(stats.vramTotalMb));
  });
}
