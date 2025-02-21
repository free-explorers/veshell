import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:nm/nm.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/shared/nm/provider/nm_client.dart';
import 'package:shell/shared/nm/provider/nm_device_added.dart';
import 'package:shell/shared/nm/provider/nm_device_removed.dart';

part 'nm_devices.g.dart';

@riverpod
class NmDevices extends _$NmDevices {
  IMap<String, NetworkManagerDevice> _addressDeviceMap =
      <String, NetworkManagerDevice>{}.lock;
  @override
  Future<ISet<String>> build() async {
    final client = await ref.watch(nmClientProvider.future);

    ref
      ..listen(nmDeviceAddedProvider, (_, device) {
        print('deviced added $device');
        ref.invalidateSelf();
      })
      ..listen(nmDeviceRemovedProvider, (_, device) {
        print('deviced removed $device');
        ref.invalidateSelf();
      });

    _addressDeviceMap =
        {for (final device in client.devices) device.hwAddress: device}.lock;

    return _addressDeviceMap.keys.toISet();
  }

  NetworkManagerDevice? getDevice(String address) => _addressDeviceMap[address];
}
