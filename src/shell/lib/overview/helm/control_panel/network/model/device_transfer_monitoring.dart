import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_transfer_monitoring.freezed.dart';

@freezed
abstract class DeviceTransferMonitoring with _$DeviceTransferMonitoring {
  factory DeviceTransferMonitoring({
    required int receivingBytesPerSecond,
    required int transferringBytesPerSecond,
  }) = _DeviceTransferMonitoring;
}
