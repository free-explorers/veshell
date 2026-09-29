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
    required List<String> actions,
    required NotificationHints hints,
    required int expireTimeout,
    /// The notification's secondary text. The freedesktop `Notify` signature
    /// makes the argument mandatory on the wire, but its value may be empty:
    /// the shell synthesizes attention notifications with a summary only.
    @Default('') String body,
  }) = _DbusNotification;

  factory DbusNotification.fromJson(Map<String, dynamic> json) =>
      _$DbusNotificationFromJson(json);
}
