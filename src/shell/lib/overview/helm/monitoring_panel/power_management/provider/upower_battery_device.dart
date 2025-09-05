import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_client.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_devices.dart';
import 'package:upower/upower.dart';

part 'upower_battery_device.g.dart';

@riverpod
Future<UPowerDevice?> upowerBatteryDevice(Ref ref) {
  return ref.watch(upowerDevicesProvider.future).then((devices) {
    return devices.firstWhere(
      (device) =>
          UpowerClient.getDeviceType(device) == UPowerDeviceType.battery,
    );
  });
}
