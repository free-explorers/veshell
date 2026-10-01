import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/disk_monitoring/provider/disk_space_cache.dart';
import 'package:shell/overview/helm/monitoring_panel/sampling/proc_files.dart';
import 'package:universal_disk_space/universal_disk_space.dart';

part 'disk_space.g.dart';

/// How often the disk list is rescanned.
///
/// `universal_disk_space` shells out to `df`, so this is deliberately much
/// slower than the `/proc` samplers.
const diskSampleInterval = Duration(seconds: 5);

/// Disk usage, rescanned while the panel is open.
@riverpod
class DiskSpaceState extends _$DiskSpaceState {
  @override
  List<Disk> build() {
    final cancel = startPolling(diskSampleInterval, _sample);
    ref.onDispose(cancel);
    // Start from the last reading so the card is populated immediately; the
    // first sample then refreshes it.
    return ref.read(diskSpaceCacheProvider);
  }

  Future<void> _sample() async {
    final diskSpace = DiskSpace();
    await diskSpace.scan();
    if (!ref.mounted) return;
    state = diskSpace.disks;
    ref.read(diskSpaceCacheProvider.notifier).disks = diskSpace.disks;
  }
}
