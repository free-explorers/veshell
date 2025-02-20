import 'package:nm/nm.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/nm/provider/nm_devices.dart';

part 'nm_statistics.g.dart';

@riverpod
class NmStatistics extends _$NmStatistics {
  @override
  NetworkManagerDeviceStatistics build(String hwAddress) {
    final device = ref.read(nmDevicesProvider.notifier).getDevice(hwAddress)!;
    final subscription = device.statistics!.propertiesChanged.listen((changes) {
      state = device.statistics!;
    });
    device.statistics!.setRefreshRateMs(500);
    ref.onDispose(() {
      device.statistics!.setRefreshRateMs(0);
      subscription.cancel();
    });
    return device.statistics!;
  }
}
