import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/request/wayland_request.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'maximize_window.model.serializable.freezed.dart';
part 'maximize_window.model.serializable.g.dart';

/// [MaximizeWindowRequest]
class MaximizeWindowRequest extends WaylandRequest {
  /// constructor
  const MaximizeWindowRequest({
    required MaximizeWindowMessage super.message,
    super.method = 'maximize_window',
  });
}

/// Model for [MaximizeWindowMessage]
@freezed
class MaximizeWindowMessage
    with _$MaximizeWindowMessage
    implements WaylandMessage {
  /// Factory
  factory MaximizeWindowMessage({
    required int surfaceId,
    required bool isMaximized,
  }) = _MaximizeWindowMessage;

  /// Creates a new [MaximizeWindowMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [MaximizeWindowMessage] instance.
  factory MaximizeWindowMessage.fromJson(Map<String, dynamic> json) =>
      _$MaximizeWindowMessageFromJson(json);
}
