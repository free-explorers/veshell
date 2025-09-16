// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_manager_state.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MonitorManagerState _$MonitorManagerStateFromJson(Map json) =>
    _MonitorManagerState(
      knownMonitorIds: ISet<String>.fromJson(
        json['knownMonitorIds'],
        (value) => value as String,
      ),
    );

Map<String, dynamic> _$MonitorManagerStateToJson(
  _MonitorManagerState instance,
) => <String, dynamic>{
  'knownMonitorIds': instance.knownMonitorIds.toJson((value) => value),
};
