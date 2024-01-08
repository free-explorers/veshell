import 'package:shell/manager/wayland/request/wayland_request.dart';

/// [StartupCompleteRequest]
class StartupCompleteRequest extends WaylandRequest {
  ///
  const StartupCompleteRequest({
    super.method = 'startup_complete',
  });
}
