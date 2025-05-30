import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';

part 'monitor_manager_state.serializable.freezed.dart';
part 'monitor_manager_state.serializable.g.dart';

@freezed
abstract class MonitorManagerState with _$MonitorManagerState {
  const factory MonitorManagerState({
    required ISet<MonitorId> knownMonitorIds,
  }) = _MonitorManagerState;

  factory MonitorManagerState.fromJson(Map<String, dynamic> json) =>
      _$MonitorManagerStateFromJson(json);
}
