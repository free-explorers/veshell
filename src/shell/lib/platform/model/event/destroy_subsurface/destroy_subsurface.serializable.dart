import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'destroy_subsurface.serializable.freezed.dart';
part 'destroy_subsurface.serializable.g.dart';

/// Model for DestroySubsurfaceMessage
@freezed
abstract class DestroySubsurfaceMessage
    with _$DestroySubsurfaceMessage
    implements PlatformMessage {
  /// Factory
  factory DestroySubsurfaceMessage({
    required SurfaceId surfaceId,
  }) = _DestroySubsurfaceMessage;

  factory DestroySubsurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$DestroySubsurfaceMessageFromJson(json);
}
