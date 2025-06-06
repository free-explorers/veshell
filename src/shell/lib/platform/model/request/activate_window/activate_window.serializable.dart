import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'activate_window.serializable.freezed.dart';
part 'activate_window.serializable.g.dart';

/// [ActivateWindowRequest]
class ActivateWindowRequest extends PlatformRequest {
  /// constructor
  const ActivateWindowRequest({
    required ActivateWindowMessage super.message,
    super.method = 'activate_window',
  });
}

/// Model for [ActivateWindowMessage]
@freezed
abstract class ActivateWindowMessage
    with _$ActivateWindowMessage
    implements PlatformMessage {
  /// Factory
  factory ActivateWindowMessage({
    required SurfaceId surfaceId,
    required bool activate,
  }) = _ActivateWindowMessage;

  /// Creates a new [ActivateWindowMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [ActivateWindowMessage] instance.
  factory ActivateWindowMessage.fromJson(Map<String, dynamic> json) =>
      _$ActivateWindowMessageFromJson(json);
}
