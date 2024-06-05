import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/x11_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'unmap_x11_surface.serializable.freezed.dart';
part 'unmap_x11_surface.serializable.g.dart';

/// Model for UnmapX11SurfaceMessage
@freezed
sealed class UnmapX11SurfaceMessage
    with _$UnmapX11SurfaceMessage
    implements WaylandMessage {
  /// Factory
  factory UnmapX11SurfaceMessage({
    required X11SurfaceId x11SurfaceId,
  }) = _UnmapX11SurfaceMessage;

  factory UnmapX11SurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$UnmapX11SurfaceMessageFromJson(json);
}
