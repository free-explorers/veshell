import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';

part 'notification.serializable.freezed.dart';
part 'notification.serializable.g.dart';

@freezed
abstract class Notification with _$Notification {
  const factory Notification({
    required int id,
    required String? appId,
    required DbusNotification dbusNotification,
    required DateTime createdAt,

    /// The window resolved from the D-Bus sender pid (or appId fallback) when
    /// the notification was received. Dialog windows are resolved to their
    /// parent persistent tile; ephemeral windows are kept as-is so overview
    /// visibility can be checked.
    WindowId? targetWindowId,
    @Default(false) bool isRead,

    /// Whether the D-Bus `NotificationClosed` signal has already been emitted.
    /// A closed notification only lives in the persisted history (and keeps its
    /// unread dot until it is seen); it has no live popup and must not be
    /// signaled closed again.
    @Default(false) bool isClosed,
  }) = _Notification;

  factory Notification.fromJson(Map<String, dynamic> json) =>
      _$NotificationFromJson(json);
}
