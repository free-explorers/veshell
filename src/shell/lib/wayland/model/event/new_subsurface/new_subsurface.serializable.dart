import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'new_subsurface.serializable.freezed.dart';
part 'new_subsurface.serializable.g.dart';

/// Model for NewSubsurfaceMessage
@freezed
sealed class NewSubsurfaceMessage
    with _$NewSubsurfaceMessage
    implements WaylandMessage {
  /// Factory
  factory NewSubsurfaceMessage({
    required SurfaceId surfaceId,
    required SurfaceId parent,
  }) = _NewSubsurfaceMessage;

  factory NewSubsurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$NewSubsurfaceMessageFromJson(json);
}
