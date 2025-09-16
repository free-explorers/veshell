// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_layout_changed.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MonitorLayoutChangedMessage _$MonitorLayoutChangedMessageFromJson(Map json) =>
    _MonitorLayoutChangedMessage(
      monitors: (json['monitors'] as List<dynamic>)
          .map((e) => Monitor.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );

Map<String, dynamic> _$MonitorLayoutChangedMessageToJson(
  _MonitorLayoutChangedMessage instance,
) => <String, dynamic>{
  'monitors': instance.monitors.map((e) => e.toJson()).toList(),
};
