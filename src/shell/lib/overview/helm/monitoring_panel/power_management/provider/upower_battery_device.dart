import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_client.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_devices.dart';
import 'package:upower/upower.dart';

part 'upower_battery_device.g.dart';

@riverpod
Future<UPowerDevice?> upowerBatteryDevice(Ref ref) async {
  final devices = await ref.watch(upowerDevicesProvider.future);
  final batteries = devices.where(
    (device) => UpowerClient.getDeviceType(device) == UPowerDeviceType.battery,
  );
  // Prefer the battery that powers the machine. A peripheral that UPower
  // mislabels as a battery (wireless keyboard/mouse) is only used as a last
  // resort, and never when it is a HID++ battery.
  return batteries.firstWhereOrNull(UpowerClient.isPowerSupply) ??
      batteries.firstWhereOrNull(
        (device) => !device.nativePath.startsWith('hidpp_battery'),
      );
}
