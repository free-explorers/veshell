import 'package:bluez/bluez.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/bluez/provider/bluez_client.dart';
import 'package:shell/shared/bluez/provider/bluez_device_added.dart';
import 'package:shell/shared/bluez/provider/bluez_device_removed.dart';

part 'bluez_devices.g.dart';

@riverpod
class BluezDevices extends _$BluezDevices {
  IMap<String, BlueZDevice> _addressDeviceMap = <String, BlueZDevice>{}.lock;
  @override
  Future<ISet<String>> build() async {
    final client = await ref.watch(bluezClientProvider.future);

    ref
      ..listen(bluezDeviceAddedProvider, (_, device) {
        print('deviced added $device');
        ref.invalidateSelf();
      })
      ..listen(bluezDeviceRemovedProvider, (_, device) {
        print('deviced removed $device');
        ref.invalidateSelf();
      });

    _addressDeviceMap =
        {for (final device in client.devices) device.address: device}.lock;

    return _addressDeviceMap.keys.toISet();
  }

  BlueZDevice? getDevice(String address) => _addressDeviceMap[address];
}
