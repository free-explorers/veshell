import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'notification_action_invoked.serializable.freezed.dart';
part 'notification_action_invoked.serializable.g.dart';

/// [NotificationActionInvokedRequest]
class NotificationActionInvokedRequest extends PlatformRequest {
  /// constructor
  const NotificationActionInvokedRequest({
    required NotificationActionInvokedMessage super.message,
    super.method = 'notification_action_invoked',
  });
}

/// The shell invoked an action of a notification: the compositor emits
/// `ActionInvoked(id, actionKey)`.
@freezed
sealed class NotificationActionInvokedMessage
    with _$NotificationActionInvokedMessage
    implements PlatformMessage {
  /// Factory
  factory NotificationActionInvokedMessage({
    required int id,
    required String actionKey,
  }) = _NotificationActionInvokedMessage;

  factory NotificationActionInvokedMessage.fromJson(
    Map<String, dynamic> json,
  ) => _$NotificationActionInvokedMessageFromJson(json);
}
