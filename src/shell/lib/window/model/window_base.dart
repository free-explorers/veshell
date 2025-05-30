import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/window/model/window_id.serializable.dart';
import 'package:shell/window/model/window_properties.serializable.dart';

/// Window
abstract class Window {
  const Window();
  WindowId get windowId;
  WindowProperties get properties;
  MetaWindowId? get metaWindowId;
}
