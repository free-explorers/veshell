import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shell/overview/helm/monitoring_panel/disk_monitoring/provider/disk_space.dart';
import 'package:shell/overview/helm/monitoring_panel/disk_monitoring/provider/disk_space_cache.dart';
import 'package:universal_disk_space/universal_disk_space.dart';

const _cached = Disk(
  devicePath: '/dev/sda1',
  mountPath: '/',
  totalSize: 100,
  usedSpace: 40,
  availableSpace: 60,
);

void main() {
  test('DiskSpaceCache retains the last reading', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(diskSpaceCacheProvider), isEmpty);
    container.read(diskSpaceCacheProvider.notifier).disks = const [_cached];
    expect(container.read(diskSpaceCacheProvider), const [_cached]);
  });

  test('DiskSpaceState starts from the cached reading', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      container.read(diskSpaceCacheProvider.notifier).disks = const [_cached];

      // Listen so the card-like subscription keeps the provider alive; the
      // first `df` scan is deferred to a timer that never fires here.
      final subscription = container.listen(diskSpaceStateProvider, (_, _) {});

      expect(subscription.read(), const [_cached]);

      subscription.close();
      container.dispose();
    });
  });
}
