import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/monitor/model/screen_configuration.serializable.dart';
import 'package:shell/shared/persistence/persistable_model.mixin.dart';

part 'monitor_configuration.serializable.freezed.dart';
part 'monitor_configuration.serializable.g.dart';

enum ScreenDisplayMode {
  splitHorizontal,
  splitVertical,
}

///
@freezed
class MonitorConfiguration
    with _$MonitorConfiguration
    implements PersistableModel {
  /// Factory
  factory MonitorConfiguration({
    required IList<ScreenConfiguration> screenList,
    required ScreenDisplayMode displayMode,
  }) = _MonitorConfiguration;
  MonitorConfiguration._();
  factory MonitorConfiguration.fromJson(Map<String, dynamic> json) =>
      _$MonitorConfigurationFromJson(json);
}
