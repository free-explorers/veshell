// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_properties.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WindowProperties _$WindowPropertiesFromJson(Map json) => _WindowProperties(
  appId: json['appId'] as String,
  pid: (json['pid'] as num?)?.toInt(),
  title: json['title'] as String?,
  windowClass: json['windowClass'] as String?,
  startupId: json['startupId'] as String?,
);

Map<String, dynamic> _$WindowPropertiesToJson(_WindowProperties instance) =>
    <String, dynamic>{
      'appId': instance.appId,
      'pid': instance.pid,
      'title': instance.title,
      'windowClass': instance.windowClass,
      'startupId': instance.startupId,
    };
