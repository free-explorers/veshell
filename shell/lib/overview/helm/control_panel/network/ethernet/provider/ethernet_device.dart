import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/control_panel/network/ethernet/model/ethernet_device.dart';
import 'package:shell/shared/nm/provider/nm_device.dart';

part 'ethernet_device.g.dart';

@riverpod
class EthernetDeviceState extends _$EthernetDeviceState {
  @override
  EthernetDevice build(String address) {
    final device = ref.watch(nmDeviceProvider(address));
    return EthernetDevice(
      nmDevice: device,
    );
  }
}
