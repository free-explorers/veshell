import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'notification_closed.serializable.freezed.dart';
part 'notification_closed.serializable.g.dart';

/// [NotificationClosedRequest]
class NotificationClosedRequest extends PlatformRequest {
  /// constructor
  const NotificationClosedRequest({
    required NotificationClosedMessage super.message,
    super.method = 'notification_closed',
  });
}

/// The shell closed a notification: the compositor emits
/// `NotificationClosed(id, reason)`. The shell only sends this when a signal
/// is actually due, keeping the close idempotent.
@freezed
sealed class NotificationClosedMessage
    with _$NotificationClosedMessage
    implements PlatformMessage {
  /// Factory
  factory NotificationClosedMessage({required int id, required int reason}) =
      _NotificationClosedMessage;

  factory NotificationClosedMessage.fromJson(Map<String, dynamic> json) =>
      _$NotificationClosedMessageFromJson(json);
}
