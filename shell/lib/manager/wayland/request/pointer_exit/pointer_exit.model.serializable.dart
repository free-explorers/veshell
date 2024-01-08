import 'package:shell/manager/wayland/request/wayland_request.dart';

/// [PointerExitRequest]
class PointerExitRequest extends WaylandRequest {
  /// constructor
  const PointerExitRequest({
    super.method = 'pointer_exit',
  });
}
