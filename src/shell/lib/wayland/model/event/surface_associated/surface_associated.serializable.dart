import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/model/x11_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'surface_associated.serializable.freezed.dart';
part 'surface_associated.serializable.g.dart';

/// Model for SurfaceAssociatedMessage
@freezed
sealed class SurfaceAssociatedMessage
    with _$SurfaceAssociatedMessage
    implements WaylandMessage {
  /// Factory
  factory SurfaceAssociatedMessage({
    required X11SurfaceId x11SurfaceId,
    required SurfaceId surfaceId,
  }) = _SurfaceAssociatedMessage;

  factory SurfaceAssociatedMessage.fromJson(Map<String, dynamic> json) =>
      _$SurfaceAssociatedMessageFromJson(json);
}
