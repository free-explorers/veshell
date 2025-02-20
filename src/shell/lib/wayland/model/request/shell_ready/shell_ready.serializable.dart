import 'package:shell/wayland/model/request/wayland_request.dart';

/// [ShellReadyRequest]
class ShellReadyRequest extends WaylandRequest {
  ///
  const ShellReadyRequest({
    super.method = 'shell_ready',
  });
}
