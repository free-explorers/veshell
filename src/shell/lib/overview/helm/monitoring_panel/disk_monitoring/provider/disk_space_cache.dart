import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:universal_disk_space/universal_disk_space.dart';

part 'disk_space_cache.g.dart';

/// The most recent disk reading.
///
/// Kept alive so a reopened card shows the last values on its first frame
/// instead of a blank panel while the next `df` scan runs; the sampler that
/// feeds it stays gated on the panel being open.
@Riverpod(keepAlive: true)
class DiskSpaceCache extends _$DiskSpaceCache {
  @override
  List<Disk> build() => const [];

  /// The cached reading.
  List<Disk> get disks => state;

  /// Replaces the cached reading.
  set disks(List<Disk> disks) => state = disks;
}
