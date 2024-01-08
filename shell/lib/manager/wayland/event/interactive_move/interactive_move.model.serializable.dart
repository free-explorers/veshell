import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'interactive_move.model.serializable.freezed.dart';
part 'interactive_move.model.serializable.g.dart';

/// Model for InteractiveMoveMessage
@freezed
class InteractiveMoveMessage
    with _$InteractiveMoveMessage
    implements WaylandMessage {
  /// Factory
  factory InteractiveMoveMessage({
    required SurfaceId surfaceId,
  }) = _InteractiveMoveMessage;

  factory InteractiveMoveMessage.fromJson(Map<String, dynamic> json) =>
      _$InteractiveMoveMessageFromJson(json);
}
