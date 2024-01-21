import 'package:shell/wayland/model/request/wayland_request.dart';

/// [PointerExitRequest]
class PointerExitRequest extends WaylandRequest {
  /// constructor
  const PointerExitRequest({
    super.method = 'pointer_exit',
  });
}
