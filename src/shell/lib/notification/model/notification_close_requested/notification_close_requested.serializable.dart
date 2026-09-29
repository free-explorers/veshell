import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'notification_close_requested.serializable.freezed.dart';
part 'notification_close_requested.serializable.g.dart';

/// A client called `CloseNotification` for a live notification.
///
/// The shell tears down the popup and decides whether a `NotificationClosed`
/// signal is due (the close is idempotent and state lives in the shell).
@freezed
sealed class NotificationCloseRequestedMessage
    with _$NotificationCloseRequestedMessage
    implements PlatformMessage {
  /// Factory
  factory NotificationCloseRequestedMessage({required int id}) =
      _NotificationCloseRequestedMessage;

  factory NotificationCloseRequestedMessage.fromJson(
    Map<String, dynamic> json,
  ) => _$NotificationCloseRequestedMessageFromJson(json);
}
