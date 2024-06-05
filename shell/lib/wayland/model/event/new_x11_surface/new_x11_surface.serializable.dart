import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/x11_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'new_x11_surface.serializable.freezed.dart';
part 'new_x11_surface.serializable.g.dart';

/// Model for NewX11SurfaceMessage
@freezed
sealed class NewX11SurfaceMessage
    with _$NewX11SurfaceMessage
    implements WaylandMessage {
  /// Factory
  factory NewX11SurfaceMessage({
    required X11SurfaceId x11SurfaceId,
    required bool overrideRedirect,
  }) = _NewX11SurfaceMessage;

  factory NewX11SurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$NewX11SurfaceMessageFromJson(json);
}
