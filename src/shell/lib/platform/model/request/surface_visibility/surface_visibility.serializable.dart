import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'surface_visibility.serializable.freezed.dart';
part 'surface_visibility.serializable.g.dart';

/// Tells the compositor which client surfaces the shell displays, so it can
/// pace the frame callbacks of the others (see `SurfaceVisibilityTracker`).
class SurfaceVisibilityRequest extends PlatformRequest {
  /// constructor
  const SurfaceVisibilityRequest({
    required SurfaceVisibilityMessage super.message,
    super.method = 'surface_visibility',
  });
}

/// Model for [SurfaceVisibilityMessage]
@freezed
abstract class SurfaceVisibilityMessage
    with _$SurfaceVisibilityMessage
    implements PlatformMessage {
  /// Factory
  ///
  /// [visible] lists the surfaces painted on screen at full rate; [limited]
  /// the surfaces painted on screen that only need a low frame rate (a paused
  /// game behind its frost). Every other surface is hidden.
  factory SurfaceVisibilityMessage({
    required List<int> visible,
    required List<int> limited,
  }) = _SurfaceVisibilityMessage;

  /// Creates a new [SurfaceVisibilityMessage] instance from a map.
  factory SurfaceVisibilityMessage.fromJson(Map<String, dynamic> json) =>
      _$SurfaceVisibilityMessageFromJson(json);
}
