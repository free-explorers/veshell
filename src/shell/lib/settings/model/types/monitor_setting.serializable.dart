import 'dart:ui';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/shared/util/json_converter/offset.dart';

part 'monitor_setting.serializable.freezed.dart';
part 'monitor_setting.serializable.g.dart';

@freezed
abstract class MonitorSetting with _$MonitorSetting {
  const factory MonitorSetting({
    required Mode mode,
    required double fractionnalScale,
    @OffsetConverter() required Offset location,
  }) = _MonitorSetting;
  factory MonitorSetting.fromJson(Map<String, dynamic> json) =>
      _$MonitorSettingFromJson(json);
}
