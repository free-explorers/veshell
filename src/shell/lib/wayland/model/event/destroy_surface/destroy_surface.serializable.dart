import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'destroy_surface.serializable.freezed.dart';
part 'destroy_surface.serializable.g.dart';

/// Model for DestroySurfaceMessage
@freezed
class DestroySurfaceMessage
    with _$DestroySurfaceMessage
    implements WaylandMessage {
  /// Factory
  factory DestroySurfaceMessage({
    required SurfaceId surfaceId,
  }) = _DestroySurfaceMessage;

  factory DestroySurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$DestroySurfaceMessageFromJson(json);
}
