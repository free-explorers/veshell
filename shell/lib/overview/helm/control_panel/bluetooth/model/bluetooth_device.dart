import 'package:bluez/bluez.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bluetooth_device.freezed.dart';

@freezed
class BluetoothDevice with _$BluetoothDevice {
  factory BluetoothDevice({
    required BlueZDevice bluezDevice,
    required bool connecting,
    required bool pairing,
  }) = _BluetoothDevice;
}
