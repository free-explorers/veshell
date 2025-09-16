// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Notification _$NotificationFromJson(Map json) => _Notification(
  id: (json['id'] as num).toInt(),
  appId: json['appId'] as String?,
  dbusNotification: DbusNotification.fromJson(
    Map<String, dynamic>.from(json['dbusNotification'] as Map),
  ),
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$NotificationToJson(_Notification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'appId': instance.appId,
      'dbusNotification': instance.dbusNotification.toJson(),
      'createdAt': instance.createdAt.toIso8601String(),
    };
