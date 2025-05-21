import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/screen/model/screen.serializable.dart';

part 'screen_configuration.serializable.freezed.dart';
part 'screen_configuration.serializable.g.dart';

@freezed
abstract class ScreenConfiguration with _$ScreenConfiguration {
  const factory ScreenConfiguration({
    required int flex,
    required ScreenId screenId,
    MonitorId? primaryForMonitor,
  }) = _ScreenConfiguration;

  factory ScreenConfiguration.fromJson(Map<String, dynamic> json) =>
      _$ScreenConfigurationFromJson(json);
}
