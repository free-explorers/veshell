import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'interactive_resize.serializable.freezed.dart';
part 'interactive_resize.serializable.g.dart';

/// Model for InteractiveResizeMessage
@freezed
class InteractiveResizeMessage
    with _$InteractiveResizeMessage
    implements WaylandMessage {
  /// Factory
  factory InteractiveResizeMessage({
    required SurfaceId surfaceId,
    required int edge,
  }) = _InteractiveResizeMessage;

  factory InteractiveResizeMessage.fromJson(Map<String, dynamic> json) =>
      _$InteractiveResizeMessageFromJson(json);
}
