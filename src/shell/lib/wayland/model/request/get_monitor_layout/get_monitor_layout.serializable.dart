import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/request/wayland_request.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'get_monitor_layout.serializable.freezed.dart';
part 'get_monitor_layout.serializable.g.dart';

/// [GetMonitorLayoutRequest]
class GetMonitorLayoutRequest extends WaylandRequest {
  /// constructor
  const GetMonitorLayoutRequest({
    required GetMonitorLayoutMessage super.message,
    super.method = 'get_monitor_layout',
  });
}

/// Model for [GetMonitorLayoutMessage]
@freezed
class GetMonitorLayoutMessage
    with _$GetMonitorLayoutMessage
    implements WaylandMessage {
  /// Factory
  factory GetMonitorLayoutMessage() = _GetMonitorLayoutMessage;

  /// Creates a new [GetMonitorLayoutMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [GetMonitorLayoutMessage] instance.
  factory GetMonitorLayoutMessage.fromJson(Map<String, dynamic> json) =>
      _$GetMonitorLayoutMessageFromJson(json);
}
