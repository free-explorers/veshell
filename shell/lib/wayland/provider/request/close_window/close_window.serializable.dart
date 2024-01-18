import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/request/wayland_request.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'close_window.serializable.freezed.dart';
part 'close_window.serializable.g.dart';

/// [CloseWindowRequest]
class CloseWindowRequest extends WaylandRequest {
  /// constructor
  const CloseWindowRequest({
    required CloseWindowMessage super.message,
    super.method = 'close_window',
  });
}

/// Model for [CloseWindowMessage]
@freezed
class CloseWindowMessage with _$CloseWindowMessage implements WaylandMessage {
  /// Factory
  factory CloseWindowMessage({
    required SurfaceId surfaceId,
  }) = _CloseWindowMessage;

  /// Creates a new [CloseWindowMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [CloseWindowMessage] instance.
  factory CloseWindowMessage.fromJson(Map<String, dynamic> json) =>
      _$CloseWindowMessageFromJson(json);
}
