import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'set_environment_variables.serializable.freezed.dart';
part 'set_environment_variables.serializable.g.dart';

/// Model for SetEnvironmentVariablesMessage
@freezed
sealed class SetEnvironmentVariablesMessage
    with _$SetEnvironmentVariablesMessage
    implements WaylandMessage {
  /// Factory
  factory SetEnvironmentVariablesMessage({
    /// A nullable value means that the variable should be unset.
    required IMap<String, String?> environmentVariables,
  }) = _SetEnvironmentVariablesMessage;

  factory SetEnvironmentVariablesMessage.fromJson(Map<String, dynamic> json) =>
      _$SetEnvironmentVariablesMessageFromJson(json);
}
