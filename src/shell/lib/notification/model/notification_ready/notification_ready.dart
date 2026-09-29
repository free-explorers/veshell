import 'package:shell/platform/model/request/platform_request.dart';

/// `NotificationReadyRequest`
///
/// Sent once the notification manager has subscribed to the compositor's
/// notification events. The compositor holds accepted `Notify`/`CloseNotification`
/// calls until this arrives, so nothing is pushed to a shell that cannot
/// receive it.
class NotificationReadyRequest extends PlatformRequest {
  /// constructor
  const NotificationReadyRequest({super.method = 'notification_ready'});
}
