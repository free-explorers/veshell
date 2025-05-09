import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/shared/util/json_converter/resize_edge.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'interactive_resize.serializable.freezed.dart';
part 'interactive_resize.serializable.g.dart';

enum ResizeEdge {
  none,
  top,
  bottom,
  left,
  topLeft,
  bottomLeft,
  right,
  topRight,
  bottomRight,
}

/// Model for InteractiveResizeMessage
@freezed
class InteractiveResizeMessage
    with _$InteractiveResizeMessage
    implements WaylandMessage {
  /// Factory
  factory InteractiveResizeMessage({
    required MetaWindowId metaWindowId,
    @ResizeEdgeConverter() required ResizeEdge edge,
  }) = _InteractiveResizeMessage;

  factory InteractiveResizeMessage.fromJson(Map<String, dynamic> json) =>
      _$InteractiveResizeMessageFromJson(json);
}
