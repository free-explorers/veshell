import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/request/wayland_request.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'resize_window.serializable.freezed.dart';
part 'resize_window.serializable.g.dart';

/// [ResizeWindowRequest]
class ResizeWindowRequest extends WaylandRequest {
  /// constructor
  const ResizeWindowRequest({
    required ResizeWindowMessage super.message,
    super.method = 'resize_window',
  });
}

/// Model for [ResizeWindowMessage]
@freezed
class ResizeWindowMessage with _$ResizeWindowMessage implements WaylandMessage {
  /// Factory
  factory ResizeWindowMessage({
    required SurfaceId surfaceId,
    required int width,
    required int height,
  }) = _ResizeWindowMessage;

  /// Creates a new [ResizeWindowMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [ResizeWindowMessage] instance.
  factory ResizeWindowMessage.fromJson(Map<String, dynamic> json) =>
      _$ResizeWindowMessageFromJson(json);
}
