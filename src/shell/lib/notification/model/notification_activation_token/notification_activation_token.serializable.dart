import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'notification_activation_token.serializable.freezed.dart';
part 'notification_activation_token.serializable.g.dart';

/// [NotificationActivationTokenRequest]
class NotificationActivationTokenRequest extends PlatformRequest {
  /// constructor
  const NotificationActivationTokenRequest({
    required NotificationActivationTokenMessage super.message,
    super.method = 'notification_activation_token',
  });
}

/// The shell is about to invoke a notification action: the compositor mints an
/// activation token for the target window and emits `ActivationToken(id,
/// token)` before the `ActionInvoked` that follows, so the sender can bring its
/// own window forward instead of the shell focusing it behind the user's back.
@freezed
sealed class NotificationActivationTokenMessage
    with _$NotificationActivationTokenMessage
    implements PlatformMessage {
  /// Factory
  factory NotificationActivationTokenMessage({
    required int id,
    required String metaWindowId,
  }) = _NotificationActivationTokenMessage;

  factory NotificationActivationTokenMessage.fromJson(
    Map<String, dynamic> json,
  ) => _$NotificationActivationTokenMessageFromJson(json);
}
