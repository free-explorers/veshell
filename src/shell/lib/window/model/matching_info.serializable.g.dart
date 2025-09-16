// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matching_info.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MatchingInfo _$MatchingInfoFromJson(Map json) => _MatchingInfo(
  appId: json['appId'] as String,
  title: json['title'] as String?,
  windowClass: json['windowClass'] as String?,
  startupId: json['startupId'] as String?,
  pid: (json['pid'] as num?)?.toInt(),
  waitingForAppSince: json['waitingForAppSince'] == null
      ? null
      : DateTime.parse(json['waitingForAppSince'] as String),
);

Map<String, dynamic> _$MatchingInfoToJson(_MatchingInfo instance) =>
    <String, dynamic>{
      'appId': instance.appId,
      'title': instance.title,
      'windowClass': instance.windowClass,
      'startupId': instance.startupId,
      'pid': instance.pid,
      'waitingForAppSince': instance.waitingForAppSince?.toIso8601String(),
    };
