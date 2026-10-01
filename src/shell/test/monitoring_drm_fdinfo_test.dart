import 'package:flutter_test/flutter_test.dart';
import 'package:shell/overview/helm/monitoring_panel/gpu_monitoring/reader/drm_fdinfo.dart';

/// A real amdgpu `fdinfo` entry, tabs and trailing units included.
const _amdFdInfo = '''
pos:
flags:\t0100002
mnt_id:\t943
ino:\t1234
drm-driver:\tamdgpu
drm-client-id:\t68
drm-pdev:\t0000:03:00.0
drm-pci-id:\t0000:03:00.0
drm-total-gtt:\t14356 KiB
drm-total-vram:\t831820 KiB
drm-memory-vram:\t831820 KiB
drm-memory-gtt: \t14356 KiB
drm-memory-cpu: \t0 KiB
drm-engine-gfx:\t241155189048 ns
drm-engine-compute:\t34708908508 ns
''';

void main() {
  group('parseDrmFdInfo', () {
    test('reads the driver, client, engines and memory regions', () {
      final info = parseDrmFdInfo(_amdFdInfo);

      expect(info, isNotNull);
      expect(info!.driver, 'amdgpu');
      expect(info.pciId, '0000:03:00.0');
      expect(info.clientId, 68);
      expect(info.engineNanoseconds['gfx'], 241155189048);
      expect(info.engineNanoseconds['compute'], 34708908508);
      expect(info.memoryKib['vram'], 831820);
      expect(info.memoryKib['gtt'], 14356);
      expect(
        info.totalEngineNanoseconds,
        241155189048 + 34708908508,
      );
    });

    test('falls back to drm-pdev when drm-pci-id is absent', () {
      const contents =
          'drm-driver:\tamdgpu\n'
          'drm-pdev:\t0000:03:00.0\n'
          'drm-engine-gfx:\t10 ns\n';
      final info = parseDrmFdInfo(contents);

      expect(info!.pciId, isNull);
      expect(info.pciDevice, '0000:03:00.0');
      expect(info.cardPciAddress, '0000:03:00.0');
    });

    test('returns null for a file that is not a DRM client', () {
      expect(parseDrmFdInfo('pos:\t0\nflags:\t0100000\n'), isNull);
    });
  });

  group('gpuBusyShares', () {
    test('computes the engine share over the elapsed interval', () {
      final shares = gpuBusyShares(
        {1: 1000000000},
        {1: 1500000000},
        1000000000,
      );

      expect(shares[1], closeTo(50, 0.001));
    });

    test('skips processes that did not touch the GPU', () {
      expect(gpuBusyShares({1: 100}, {1: 100}, 1000000), isEmpty);
    });

    test('returns nothing for a non-positive interval', () {
      expect(gpuBusyShares({1: 0}, {1: 100}, 0), isEmpty);
    });
  });
}
