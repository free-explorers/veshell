import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';

part 'notification.serializable.freezed.dart';
part 'notification.serializable.g.dart';

@freezed
abstract class Notification with _$Notification {
  const factory Notification({
    required int id,
    required String? appId,
    required DbusNotification dbusNotification,
    required DateTime createdAt,
  }) = _Notification;

  factory Notification.fromJson(Map<String, dynamic> json) =>
      _$NotificationFromJson(json);
}
