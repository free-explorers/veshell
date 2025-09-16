// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'window_id.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DialogWindowId _$DialogWindowIdFromJson(Map json) => DialogWindowId(
  json['uuid'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$DialogWindowIdToJson(DialogWindowId instance) =>
    <String, dynamic>{'uuid': instance.uuid, 'runtimeType': instance.$type};

PersistentWindowId _$PersistentWindowIdFromJson(Map json) => PersistentWindowId(
  json['uuid'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$PersistentWindowIdToJson(PersistentWindowId instance) =>
    <String, dynamic>{'uuid': instance.uuid, 'runtimeType': instance.$type};

EphemeralWindowId _$EphemeralWindowIdFromJson(Map json) => EphemeralWindowId(
  json['uuid'] as String,
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$EphemeralWindowIdToJson(EphemeralWindowId instance) =>
    <String, dynamic>{'uuid': instance.uuid, 'runtimeType': instance.$type};
