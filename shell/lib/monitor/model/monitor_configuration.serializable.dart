import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/shared/persistence/persistable_model.mixin.dart';

part 'monitor_configuration.serializable.freezed.dart';
part 'monitor_configuration.serializable.g.dart';

///
@freezed
class MonitorConfiguration
    with _$MonitorConfiguration
    implements PersistableModel {
  /// Factory
  factory MonitorConfiguration({
    required int selectedMode,
    required ScreenConfiguration screenConfiguration,
  }) = _MonitorConfiguration;
  MonitorConfiguration._();
  factory MonitorConfiguration.fromJson(Map<String, dynamic> json) =>
      _$MonitorConfigurationFromJson(json);
}
