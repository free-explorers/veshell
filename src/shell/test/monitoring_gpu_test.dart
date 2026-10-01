import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/model/gpu_stats.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_device.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_parsing.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/gpu_stats_reader.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/intel.dart';

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

  group('vramUsedPercent', () {
    test('computes the share of VRAM in use', () {
      expect(
        vramUsedPercent(
          const GpuStats(vramUsedMb: 512, vramTotalMb: 1024),
        ),
        closeTo(50, 0.001),
      );
    });

    test('returns zero without a VRAM total', () {
      expect(
        vramUsedPercent(const GpuStats(vramUsedMb: 512)),
        0,
      );
    });
  });

  group('intelLoadFromFrequency', () {
    test('scales between the min and max frequency', () {
      expect(
        intelLoadFromFrequency(current: 800, min: 300, max: 1300),
        50,
      );
    });

    test('clamps to 0..100', () {
      expect(
        intelLoadFromFrequency(current: 2000, min: 300, max: 1300),
        100,
      );
      expect(
        intelLoadFromFrequency(current: 0, min: 300, max: 1300),
        0,
      );
    });

    test('returns null without a usable range', () {
      expect(intelLoadFromFrequency(current: 800), isNull);
      expect(
        intelLoadFromFrequency(current: 800, min: 800, max: 800),
        isNull,
      );
    });
  });

  group('selectGpuDevice', () {
    const card0 = GpuDevice(
      cardPath: '/sys/class/drm/card0',
      driver: 'amdgpu',
      vendor: GpuVendor.amd,
    );
    const card1 = GpuDevice(
      cardPath: '/sys/class/drm/card1',
      driver: 'amdgpu',
      vendor: GpuVendor.amd,
      isBootVga: true,
    );
    const card2 = GpuDevice(
      cardPath: '/sys/class/drm/card2',
      driver: 'amdgpu',
      vendor: GpuVendor.amd,
    );

    test('returns null without candidates', () {
      expect(selectGpuDevice(const []), isNull);
    });

    test('prefers the boot VGA over a lower-numbered card', () {
      expect(
        selectGpuDevice(const [card0, card1])?.cardPath,
        card1.cardPath,
      );
    });

    test('falls back to the first card when none is the boot VGA', () {
      expect(
        selectGpuDevice(const [card0, card2])?.cardPath,
        card0.cardPath,
      );
    });

    test('honours a DRM_DEVICE card override', () {
      expect(
        selectGpuDevice(
          const [card0, card1],
          devicePathOverride: '/dev/dri/card0',
        )?.cardPath,
        card0.cardPath,
      );
    });

    test('resolves a DRM_DEVICE render node through the map', () {
      expect(
        selectGpuDevice(
          const [card0, card1],
          devicePathOverride: '/dev/dri/renderD128',
          renderNodeToCard: const {'renderD128': card1},
        )?.cardPath,
        card1.cardPath,
      );
    });

    test('ignores an unknown override and keeps the default choice', () {
      expect(
        selectGpuDevice(
          const [card0, card1],
          devicePathOverride: '/dev/dri/renderD999',
        )?.cardPath,
        card1.cardPath,
      );
    });
  });

  test('reads a live amdgpu sysfs when one is present', () async {
    // No supported GPU (or not Linux): there is nothing to assert.
    if (!_hasSupportedCard()) return;

    final device = detectGpuDevice();
    expect(
      device,
      isNotNull,
      reason: 'a supported card exposes gpu_busy_percent but was not detected',
    );

    final stats = await readGpuStats(device!);
    expect(stats, isNotNull);
    expect(stats!.load, inInclusiveRange(0, 100));
    expect(stats.vramTotalMb, greaterThan(0));
    expect(stats.vramUsedMb, lessThanOrEqualTo(stats.vramTotalMb));
  });
}

/// Whether this machine has a DRM card exposing the amdgpu busy counter.
bool _hasSupportedCard() {
  final drm = Directory('/sys/class/drm');
  if (!drm.existsSync()) return false;
  final pattern = RegExp(r'^card\d+$');
  try {
    for (final entity in drm.listSync()) {
      if (entity is! Directory) continue;
      if (!pattern.hasMatch(p.basename(entity.path))) continue;
      if (File('${entity.path}/device/gpu_busy_percent').existsSync()) {
        return true;
      }
    }
  } on FileSystemException {
    return false;
  }
  return false;
}
