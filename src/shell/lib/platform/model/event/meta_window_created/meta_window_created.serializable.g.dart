// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meta_window_created.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MetaWindowCreatedMessage _$MetaWindowCreatedMessageFromJson(Map json) =>
    _MetaWindowCreatedMessage(
      id: json['id'] as String,
      pid: (json['pid'] as num).toInt(),
      mapped: json['mapped'] as bool,
      surfaceId: (json['surfaceId'] as num).toInt(),
      needDecoration: json['needDecoration'] as bool,
      gameModeActivated: json['gameModeActivated'] as bool,
      scaleRatio: (json['scaleRatio'] as num).toDouble(),
      appId: json['appId'] as String?,
      parent: json['parent'] as String?,
      displayMode: json['displayMode'] as String?,
      title: json['title'] as String?,
      windowClass: json['windowClass'] as String?,
      startupId: json['startupId'] as String?,
      geometry: _$JsonConverterFromJson<Map<dynamic, dynamic>, Rect>(
        json['geometry'],
        const RectConverter().fromJson,
      ),
    );

Map<String, dynamic> _$MetaWindowCreatedMessageToJson(
  _MetaWindowCreatedMessage instance,
) => <String, dynamic>{
  'id': instance.id,
  'pid': instance.pid,
  'mapped': instance.mapped,
  'surfaceId': instance.surfaceId,
  'needDecoration': instance.needDecoration,
  'gameModeActivated': instance.gameModeActivated,
  'scaleRatio': instance.scaleRatio,
  'appId': instance.appId,
  'parent': instance.parent,
  'displayMode': instance.displayMode,
  'title': instance.title,
  'windowClass': instance.windowClass,
  'startupId': instance.startupId,
  'geometry': _$JsonConverterToJson<Map<dynamic, dynamic>, Rect>(
    instance.geometry,
    const RectConverter().toJson,
  ),
};

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) => json == null ? null : fromJson(json as Json);

Json? _$JsonConverterToJson<Json, Value>(
  Value? value,
  Json? Function(Value value) toJson,
) => value == null ? null : toJson(value);
