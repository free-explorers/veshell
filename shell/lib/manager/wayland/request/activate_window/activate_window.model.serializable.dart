import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/request/wayland_request.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'activate_window.model.serializable.freezed.dart';
part 'activate_window.model.serializable.g.dart';

/// [ActivateWindowRequest]
class ActivateWindowRequest extends WaylandRequest {
  /// constructor
  const ActivateWindowRequest({
    required ActivateWindowMessage super.message,
    super.method = 'activate_window',
  });
}

/// Model for [ActivateWindowMessage]
@freezed
class ActivateWindowMessage
    with _$ActivateWindowMessage
    implements WaylandMessage {
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
