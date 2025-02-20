import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/notification/model/notification_hints.serializable.dart';

part 'dbus_notification.serializable.freezed.dart';
part 'dbus_notification.serializable.g.dart';

@freezed
abstract class DbusNotification with _$DbusNotification {
  const factory DbusNotification({
    required int? pid,
    required String appName,
    required int replacesId,
    required String appIcon,
    required String summary,
    required String body,
    required List<String> actions,
    required NotificationHints hints,
    required int expireTimeout,
  }) = _DbusNotification;

  factory DbusNotification.fromJson(Map<String, dynamic> json) =>
      _$DbusNotificationFromJson(json);
}
