// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_meta_window.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NewMetaWindowMessageImpl _$$NewMetaWindowMessageImplFromJson(Map json) =>
    _$NewMetaWindowMessageImpl(
      id: json['id'] as String,
      pid: (json['pid'] as num).toInt(),
      mapped: json['mapped'] as bool,
      appId: json['appId'] as String?,
      parent: json['parent'] as String?,
      displayMode: json['displayMode'] as String?,
      title: json['title'] as String?,
      windowClass: json['windowClass'] as String?,
      startupId: json['startupId'] as String?,
    );

Map<String, dynamic> _$$NewMetaWindowMessageImplToJson(
        _$NewMetaWindowMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'pid': instance.pid,
      'mapped': instance.mapped,
      'appId': instance.appId,
      'parent': instance.parent,
      'displayMode': instance.displayMode,
      'title': instance.title,
      'windowClass': instance.windowClass,
      'startupId': instance.startupId,
    };
