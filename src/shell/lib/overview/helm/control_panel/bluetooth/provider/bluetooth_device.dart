import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/control_panel/bluetooth/model/bluetooth_device.dart';
import 'package:shell/shared/bluez/provider/bluez_device.dart';

part 'bluetooth_device.g.dart';

@riverpod
class BluetoothDeviceState extends _$BluetoothDeviceState {
  @override
  BluetoothDevice? build(String address) {
    final device = ref.watch(bluezDeviceProvider(address));
    if (device == null) {
      return null;
    }
    return BluetoothDevice(
      bluezDevice: device,
      connecting: false,
      pairing: false,
    );
  }

  Future<void> connect() async {
    state = state?.copyWith(connecting: true);
    try {
      await state?.bluezDevice.connect();
    } catch (e) {
      print('connect error $e');
    }
    state = state?.copyWith(connecting: false);
  }

  Future<void> pair() async {
    state = state?.copyWith(pairing: true);
    try {
      await state?.bluezDevice.pair();
    } catch (e) {
      print('pair error $e');
    }
    state = state?.copyWith(pairing: false);
    await connect();
  }
}
