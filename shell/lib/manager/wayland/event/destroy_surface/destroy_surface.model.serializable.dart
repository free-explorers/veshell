import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'destroy_surface.model.serializable.freezed.dart';
part 'destroy_surface.model.serializable.g.dart';

/// Model for DestroySurfaceMessage
@freezed
class DestroySurfaceMessage
    with _$DestroySurfaceMessage
    implements WaylandMessage {
  /// Factory
  factory DestroySurfaceMessage({
    required int surfaceId,
  }) = _DestroySurfaceMessage;

  factory DestroySurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$DestroySurfaceMessageFromJson(json);
}
