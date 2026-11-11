import 'package:dbus/dbus.dart';
import 'package:nm/nm.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/control_panel/network/wifi/model/wifi_manager_state.dart';
import 'package:shell/shared/nm/provider/nm_client.dart';
import 'package:shell/shared/nm/provider/nm_devices.dart';

part 'wifi_manager.g.dart';

@Riverpod(keepAlive: true)
class WifiManager extends _$WifiManager {
  @override
  WifiManagerState build(String address) {
    return WifiManagerState(isScanning: false);
  }

  NetworkManagerDevice get _device =>
      ref.read(nmDevicesProvider.notifier).getDevice(address)!;

  Future<void> scan() async {
    if (state.isScanning) return;
    final wireless = _device.wireless!;
    final listenToLastScan = wireless.propertiesChanged
        .firstWhere((properties) => properties.contains('LastScan'))
        .then((_) {
          state = state.copyWith(isScanning: false);
        });
    await wireless.requestScan();
    state = state.copyWith(isScanning: true);
    await listenToLastScan;
  }

  Future<void> connectToAccessPoint(
    NetworkManagerAccessPoint accessPoint,
    String securityKey,
  ) async {
    final client = ref.read(nmClientProvider).value!;
    final device = _device;
    client.addAndActivateConnection(
      connection: {
        '802-11-wireless-security': {
          'key-mgmt': const DBusString('wpa-psk'),
          'psk': DBusString(securityKey),
        },
      },
      device: device,
      accessPoint: accessPoint,
    );
    final newConnection = await client.activeConnectionAdded.first;
    print(newConnection);
    print(newConnection.state);
    print(newConnection.stateFlags);
  }
}
