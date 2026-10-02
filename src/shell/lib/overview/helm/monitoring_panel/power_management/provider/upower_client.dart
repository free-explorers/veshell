import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:upower/upower.dart';

part 'upower_client.g.dart';

@riverpod
class UpowerClient extends _$UpowerClient {
  @override
  Future<UPowerClient> build() async {
    final client = UPowerClient();
    await client.connect();
    ref.onDispose(client.close);
    return client;
  }

  static UPowerDeviceType getDeviceType(UPowerDevice device) {
    try {
      return device.type;
    } on Object catch (_) {
      return UPowerDeviceType.unknown;
    }
  }

  /// Whether [device] powers the machine, as opposed to only powering itself
  /// (a wireless keyboard, mouse, headset, ...). UPower reports the same
  /// [UPowerDeviceType.battery] for both when the driver cannot tell a
  /// peripheral apart, so this is the discriminator between the system
  /// battery and a peripheral one.
  static bool isPowerSupply(UPowerDevice device) {
    try {
      return device.powerSupply;
    } on Object catch (_) {
      return false;
    }
  }

  /// The battery that powers the machine itself, as opposed to a peripheral
  /// battery. See [isPowerSupply].
  static bool isSystemBattery(UPowerDevice device) =>
      getDeviceType(device) == UPowerDeviceType.battery &&
      isPowerSupply(device);
}
