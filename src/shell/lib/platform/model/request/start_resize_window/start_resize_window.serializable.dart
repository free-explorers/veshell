import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/platform/model/event/interactive_resize/interactive_resize.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

/// Starts a compositor-owned interactive resize for a floating window.
///
/// Flutter remains responsible for painting and hit-testing the visual resize
/// handles; Rust owns the pointer for the duration of the gesture and publishes
/// the resulting rect.
class StartResizeWindowRequest extends PlatformRequest {
  const StartResizeWindowRequest({
    required StartResizeWindowMessage super.message,
    super.method = 'start_resize_window',
  });
}

/// Edge is sent as the `MetaResizeEdge` bit value expected by Rust.
class StartResizeWindowMessage implements PlatformMessage {
  const StartResizeWindowMessage({
    required this.metaWindowId,
    required this.edge,
  });

  final MetaWindowId metaWindowId;
  final ResizeEdge edge;

  @override
  Map<String, dynamic> toJson() => {
    'metaWindowId': metaWindowId,
    'edge': _resizeEdgeBits(edge),
  };
}

int _resizeEdgeBits(ResizeEdge edge) => switch (edge) {
  ResizeEdge.none => 0,
  ResizeEdge.top => 1,
  ResizeEdge.bottom => 2,
  ResizeEdge.left => 4,
  ResizeEdge.topLeft => 5,
  ResizeEdge.bottomLeft => 6,
  ResizeEdge.right => 8,
  ResizeEdge.topRight => 9,
  ResizeEdge.bottomRight => 10,
};
