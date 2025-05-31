import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'get_environment_variables.serializable.freezed.dart';
part 'get_environment_variables.serializable.g.dart';

/// [GetEnvironmentVariablesRequest]
class GetEnvironmentVariablesRequest extends PlatformRequest {
  /// constructor
  const GetEnvironmentVariablesRequest({
    required GetEnvironmentVariablesMessage super.message,
    super.method = 'get_environment_variables',
  });
}

/// Model for [GetEnvironmentVariablesMessage]
@freezed
abstract class GetEnvironmentVariablesMessage
    with _$GetEnvironmentVariablesMessage
    implements PlatformMessage {
  /// Factory
  factory GetEnvironmentVariablesMessage() = _GetEnvironmentVariablesMessage;

  /// Creates a new [GetEnvironmentVariablesMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [GetEnvironmentVariablesMessage] instance.
  factory GetEnvironmentVariablesMessage.fromJson(Map<String, dynamic> json) =>
      _$GetEnvironmentVariablesMessageFromJson(json);
}
