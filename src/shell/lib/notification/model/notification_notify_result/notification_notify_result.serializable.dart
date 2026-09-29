import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'notification_notify_result.serializable.freezed.dart';
part 'notification_notify_result.serializable.g.dart';

/// [NotificationNotifyResultRequest]
class NotificationNotifyResultRequest extends PlatformRequest {
  /// constructor
  const NotificationNotifyResultRequest({
    required NotificationNotifyResultMessage super.message,
    super.method = 'notification_notify_result',
  });
}

/// The shell's answer to a forwarded `Notify`: the id it assigned. Completes
/// the compositor's pending D-Bus reply for that call.
@freezed
sealed class NotificationNotifyResultMessage
    with _$NotificationNotifyResultMessage
    implements PlatformMessage {
  /// Factory
  factory NotificationNotifyResultMessage({
    required int callToken,
    required int id,
  }) = _NotificationNotifyResultMessage;

  factory NotificationNotifyResultMessage.fromJson(Map<String, dynamic> json) =>
      _$NotificationNotifyResultMessageFromJson(json);
}
