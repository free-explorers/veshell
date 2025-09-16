// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dbus_notification.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DbusNotification _$DbusNotificationFromJson(Map json) => _DbusNotification(
  pid: (json['pid'] as num?)?.toInt(),
  appName: json['appName'] as String,
  replacesId: (json['replacesId'] as num).toInt(),
  appIcon: json['appIcon'] as String,
  summary: json['summary'] as String,
  body: json['body'] as String,
  actions: (json['actions'] as List<dynamic>).map((e) => e as String).toList(),
  hints: NotificationHints.fromJson(
    Map<String, dynamic>.from(json['hints'] as Map),
  ),
  expireTimeout: (json['expireTimeout'] as num).toInt(),
);

Map<String, dynamic> _$DbusNotificationToJson(_DbusNotification instance) =>
    <String, dynamic>{
      'pid': instance.pid,
      'appName': instance.appName,
      'replacesId': instance.replacesId,
      'appIcon': instance.appIcon,
      'summary': instance.summary,
      'body': instance.body,
      'actions': instance.actions,
      'hints': instance.hints.toJson(),
      'expireTimeout': instance.expireTimeout,
    };
