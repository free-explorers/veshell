import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/window/model/window_id.dart';
import 'package:shell/window/model/window_properties.serializable.dart';

/// Window
abstract class Window {
  const Window({
    required this.properties,
    required this.windowId,
    required this.metaWindowId,
  });

  final WindowId windowId;
  final WindowProperties properties;
  final MetaWindowId? metaWindowId;
}
