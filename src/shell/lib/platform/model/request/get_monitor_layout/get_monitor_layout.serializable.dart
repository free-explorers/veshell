import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'get_monitor_layout.serializable.freezed.dart';
part 'get_monitor_layout.serializable.g.dart';

/// [GetMonitorLayoutRequest]
class GetMonitorLayoutRequest extends PlatformRequest {
  /// constructor
  const GetMonitorLayoutRequest({
    required GetMonitorLayoutMessage super.message,
    super.method = 'get_monitor_layout',
  });
}

/// Model for [GetMonitorLayoutMessage]
@freezed
abstract class GetMonitorLayoutMessage
    with _$GetMonitorLayoutMessage
    implements PlatformMessage {
  /// Factory
  factory GetMonitorLayoutMessage() = _GetMonitorLayoutMessage;

  /// Creates a new [GetMonitorLayoutMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [GetMonitorLayoutMessage] instance.
  factory GetMonitorLayoutMessage.fromJson(Map<String, dynamic> json) =>
      _$GetMonitorLayoutMessageFromJson(json);
}
