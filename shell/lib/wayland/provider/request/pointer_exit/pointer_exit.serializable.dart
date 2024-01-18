import 'package:shell/wayland/provider/request/wayland_request.dart';

/// [PointerExitRequest]
class PointerExitRequest extends WaylandRequest {
  /// constructor
  const PointerExitRequest({
    super.method = 'pointer_exit',
  });
}
