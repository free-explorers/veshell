import 'package:bluez/bluez.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/bluez/provider/bluez_devices.dart';

part 'bluez_device.g.dart';

@riverpod
class BluezDevice extends _$BluezDevice {
  @override
  BlueZDevice build(String address) {
    final device = ref.read(bluezDevicesProvider.notifier).getDevice(address)!;
    final subscription = device.propertiesChanged.listen((changes) {
      print('propertiesChanged $changes');
      ref.notifyListeners();
    });

    ref.onDispose(() {
      print('dispose BlueZDevice ');
      subscription.cancel();
    });
    return device;
  }
}
