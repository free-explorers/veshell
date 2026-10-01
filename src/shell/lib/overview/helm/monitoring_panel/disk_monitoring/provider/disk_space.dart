import 'package:riverpod_annotation/riverpod_annotation.dart';
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
    return const [];
  }

  Future<void> _sample() async {
    final diskSpace = DiskSpace();
    await diskSpace.scan();
    if (!ref.mounted) return;
    state = diskSpace.disks;
  }
}
