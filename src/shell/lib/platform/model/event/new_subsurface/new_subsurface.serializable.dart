import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'new_subsurface.serializable.freezed.dart';
part 'new_subsurface.serializable.g.dart';

/// Model for NewSubsurfaceMessage
@freezed
sealed class NewSubsurfaceMessage
    with _$NewSubsurfaceMessage
    implements PlatformMessage {
  /// Factory
  factory NewSubsurfaceMessage({
    required SurfaceId surfaceId,
    required SurfaceId parent,
  }) = _NewSubsurfaceMessage;

  factory NewSubsurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$NewSubsurfaceMessageFromJson(json);
}
