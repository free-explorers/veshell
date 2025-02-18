import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/shared/util/json_converter/offset.dart';

part 'monitor_configuration.serializable.freezed.dart';
part 'monitor_configuration.serializable.g.dart';

@freezed
class MonitorConfiguration with _$MonitorConfiguration {
  const factory MonitorConfiguration({
    required Mode mode,
    @OffsetConverter() required Offset location,
  }) = _MonitorConfiguration;
  factory MonitorConfiguration.fromJson(Map<String, dynamic> json) =>
      _$MonitorConfigurationFromJson(json);
}
