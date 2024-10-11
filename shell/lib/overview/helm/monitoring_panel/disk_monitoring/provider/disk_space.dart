import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:universal_disk_space/universal_disk_space.dart';

part 'disk_space.g.dart';

@Riverpod(keepAlive: true)
class DiskSpaceState extends _$DiskSpaceState {
  @override
  List<Disk> build() {
    // Initializes the DiskSpace class.
    final diskSpace = DiskSpace();

    // Scan for disks in the system.
    diskSpace.scan().then((_) {
      state = diskSpace.disks;
    });

    return diskSpace.disks;
  }
}
