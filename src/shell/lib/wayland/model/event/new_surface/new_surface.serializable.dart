import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'new_surface.serializable.freezed.dart';
part 'new_surface.serializable.g.dart';

/// Model for NewSurfaceMessage
@freezed
sealed class NewSurfaceMessage
    with _$NewSurfaceMessage
    implements WaylandMessage {
  /// Factory
  factory NewSurfaceMessage({
    required SurfaceId surfaceId,
  }) = _NewSurfaceMessage;

  factory NewSurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$NewSurfaceMessageFromJson(json);
}
