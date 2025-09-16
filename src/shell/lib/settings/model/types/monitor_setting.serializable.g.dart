// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_setting.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MonitorSetting _$MonitorSettingFromJson(Map json) => _MonitorSetting(
  mode: Mode.fromJson(Map<String, dynamic>.from(json['mode'] as Map)),
  fractionnalScale: (json['fractionnalScale'] as num).toDouble(),
  location: const OffsetIntConverter().fromJson(json['location'] as Map),
);

Map<String, dynamic> _$MonitorSettingToJson(_MonitorSetting instance) =>
    <String, dynamic>{
      'mode': instance.mode.toJson(),
      'fractionnalScale': instance.fractionnalScale,
      'location': const OffsetIntConverter().toJson(instance.location),
    };
