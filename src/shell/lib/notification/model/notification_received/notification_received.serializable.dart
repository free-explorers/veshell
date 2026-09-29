import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/notification/model/dbus_notification.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'notification_received.serializable.freezed.dart';
part 'notification_received.serializable.g.dart';

/// The compositor accepted a `Notify` D-Bus call and forwards it to the shell.
///
/// [callToken] correlates the shell's answer (`notification_notify_result`):
/// the D-Bus reply to the caller completes with the id the shell assigns.
@freezed
sealed class NotificationReceivedMessage
    with _$NotificationReceivedMessage
    implements PlatformMessage {
  /// Factory
  factory NotificationReceivedMessage({
    required int callToken,
    required DbusNotification notification,
  }) = _NotificationReceivedMessage;

  factory NotificationReceivedMessage.fromJson(Map<String, dynamic> json) =>
      _$NotificationReceivedMessageFromJson(json);
}
