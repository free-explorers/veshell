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

    /// The exact MetaWindow instance the notification was about when it was
    /// received (from the sender pid, or the requesting window for a
    /// synthesized attention notification). It is runtime-only identity: a
    /// relaunched app gets a new MetaWindow id, so an old notification stays
    /// historical. `null` for notifications not tied to a live window (system
    /// senders).
    String? targetMetaWindowId,
    @Default(false) bool isRead,

    /// Whether the D-Bus `NotificationClosed` signal has already been emitted.
    /// A closed notification only lives in the persisted history (and keeps its
    /// unread dot until it is seen); it has no live popup and must not be
    /// signaled closed again.
    @Default(false) bool isClosed,

    /// Whether the shell synthesized this notification instead of receiving it
    /// from a D-Bus `Notify` call (e.g. a window attention request). Synthetic
    /// notifications have no external sender, so no `NotificationClosed` /
    /// `ActionInvoked` signal is ever emitted for them.
    @Default(false) bool isSynthetic,
  }) = _Notification;

  factory Notification.fromJson(Map<String, dynamic> json) =>
      _$NotificationFromJson(json);
}
