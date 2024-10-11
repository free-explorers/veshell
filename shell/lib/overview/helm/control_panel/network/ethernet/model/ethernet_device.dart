import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nm/nm.dart';

part 'ethernet_device.freezed.dart';

@freezed
class EthernetDevice with _$EthernetDevice {
  factory EthernetDevice({
    required NetworkManagerDevice nmDevice,
  }) = _EthernetDevice;
}
