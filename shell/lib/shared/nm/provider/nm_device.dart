import 'package:nm/nm.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/nm/provider/nm_devices.dart';

part 'nm_device.g.dart';

@riverpod
class NmDevice extends _$NmDevice {
  @override
  NetworkManagerDevice build(String hwAddress) {
    final device = ref.read(nmDevicesProvider.notifier).getDevice(hwAddress)!;
    final subscription = device.propertiesChanged.listen((changes) {
      print('propertiesChanged $changes');
      ref.notifyListeners();
    });

    ref.onDispose(() {
      print('dispose nmDevice ');
      subscription.cancel();
    });
    return device;
  }
}
