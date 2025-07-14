import 'package:collection/collection.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_client.dart';
import 'package:shell/overview/helm/monitoring_panel/power_management/provider/upower_devices.dart';
import 'package:upower/upower.dart';

part 'any_upower_device.g.dart';

@riverpod
bool anyUpowerDevice(Ref ref) {
  return ref
          .watch(upowerDevicesProvider)
          .value
          ?.whereNot(
            (device) =>
                UpowerClient.getDeviceType(device) ==
                UPowerDeviceType.linePower,
          )
          .isNotEmpty ??
      false;
}
