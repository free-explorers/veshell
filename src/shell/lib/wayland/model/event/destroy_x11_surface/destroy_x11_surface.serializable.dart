import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/x11_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'destroy_x11_surface.serializable.freezed.dart';

part 'destroy_x11_surface.serializable.g.dart';

/// Model for DestroyX11SurfaceMessage
@freezed
class DestroyX11SurfaceMessage
    with _$DestroyX11SurfaceMessage
    implements WaylandMessage {
  /// Factory
  factory DestroyX11SurfaceMessage({
    required X11SurfaceId x11SurfaceId,
  }) = _DestroyX11SurfaceMessage;

  factory DestroyX11SurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$DestroyX11SurfaceMessageFromJson(json);
}
