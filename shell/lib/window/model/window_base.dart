import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/window_id.dart';

/// Window
abstract class Window {
  const Window({
    required this.appId,
    required this.title,
    required this.windowId,
    required this.surfaceId,
  });

  final WindowId windowId;
  final String appId;
  final String title;
  final SurfaceId? surfaceId;
}
