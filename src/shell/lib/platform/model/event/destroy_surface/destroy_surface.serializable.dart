import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'destroy_surface.serializable.freezed.dart';
part 'destroy_surface.serializable.g.dart';

/// Model for DestroySurfaceMessage
@freezed
abstract class DestroySurfaceMessage
    with _$DestroySurfaceMessage
    implements PlatformMessage {
  /// Factory
  factory DestroySurfaceMessage({
    required SurfaceId surfaceId,
  }) = _DestroySurfaceMessage;

  factory DestroySurfaceMessage.fromJson(Map<String, dynamic> json) =>
      _$DestroySurfaceMessageFromJson(json);
}
