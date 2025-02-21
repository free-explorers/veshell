import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';

/// Window
abstract class Window {
  const Window({
    required this.properties,
    required this.windowId,
    required this.surfaceId,
  });

  final WindowId windowId;
  final WindowProperties properties;
  final SurfaceId? surfaceId;
}
