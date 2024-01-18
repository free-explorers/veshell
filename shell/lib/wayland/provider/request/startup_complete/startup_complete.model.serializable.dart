import 'package:shell/wayland/provider/request/wayland_request.dart';

/// [StartupCompleteRequest]
class StartupCompleteRequest extends WaylandRequest {
  ///
  const StartupCompleteRequest({
    super.method = 'startup_complete',
  });
}
