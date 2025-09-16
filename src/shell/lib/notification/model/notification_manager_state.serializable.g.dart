// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_manager_state.serializable.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationManagerState _$NotificationManagerStateFromJson(Map json) =>
    _NotificationManagerState(
      notificationMap: IMap<int, Notification>.fromJson(
        Map<String, Object?>.from(json['notificationMap'] as Map),
        (value) => (value as num).toInt(),
        (value) =>
            Notification.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
      lastIndex: (json['lastIndex'] as num).toInt(),
    );

Map<String, dynamic> _$NotificationManagerStateToJson(
  _NotificationManagerState instance,
) => <String, dynamic>{
  'notificationMap': instance.notificationMap.toJson(
    (value) => value,
    (value) => value.toJson(),
  ),
  'lastIndex': instance.lastIndex,
};
