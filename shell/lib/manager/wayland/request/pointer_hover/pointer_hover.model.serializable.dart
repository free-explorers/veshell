import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/request/wayland_request.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'pointer_hover.model.serializable.freezed.dart';
part 'pointer_hover.model.serializable.g.dart';

/// [PointerHoverRequest]
class PointerHoverRequest extends WaylandRequest {
  /// constructor
  const PointerHoverRequest({
    required PointerHoverMessage super.message,
    super.method = 'pointer_hover',
  });
}

/// Model for [PointerHoverMessage]
@freezed
class PointerHoverMessage with _$PointerHoverMessage implements WaylandMessage {
  /// Factory
  factory PointerHoverMessage({
    required SurfaceId surfaceId,
    required double x,
    required double y,
  }) = _PointerHoverMessage;

  /// Creates a new [PointerHoverMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [PointerHoverMessage] instance.
  factory PointerHoverMessage.fromJson(Map<String, dynamic> json) =>
      _$PointerHoverMessageFromJson(json);
}
