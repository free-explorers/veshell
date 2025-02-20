import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'destroy_xdg_surface.serializable.freezed.dart';

part 'destroy_xdg_surface.serializable.g.dart';

/// Model for DestroyXdgSurfaceMessage
@freezed
class DestroyXdgSurfaceMessage
    with _$DestroyXdgSurfaceMessage
    implements WaylandMessage {
  /// Factory
  factory DestroyXdgSurfaceMessage({
    required SurfaceId surfaceId,
  }) = _DestroyXdgSurfaceMessage;

  factory DestroyXdgSurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$DestroyXdgSurfaceMessageFromJson(json);
}
