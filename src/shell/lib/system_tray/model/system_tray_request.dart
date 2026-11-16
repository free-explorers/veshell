import 'package:shell/platform/model/request/platform_request.dart';

/// `SystemTrayReadyRequest`
///
/// Sent once the system tray manager has subscribed to the compositor's tray
/// events. The compositor then delivers every item registered so far, and the
/// changes that follow.
class SystemTrayReadyRequest extends PlatformRequest {
  /// constructor
  const SystemTrayReadyRequest({super.method = 'system_tray_ready'});
}
