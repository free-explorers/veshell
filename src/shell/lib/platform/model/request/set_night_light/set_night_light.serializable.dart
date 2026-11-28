import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'set_night_light.serializable.freezed.dart';
part 'set_night_light.serializable.g.dart';

/// [SetNightLightRequest]: the Helm's Night Light toggle.
class SetNightLightRequest extends PlatformRequest {
  /// constructor
  const SetNightLightRequest({
    required SetNightLightMessage super.message,
    super.method = 'set_night_light',
  });
}

/// Model for [SetNightLightMessage]
@freezed
abstract class SetNightLightMessage
    with _$SetNightLightMessage
    implements PlatformMessage {
  /// Factory: [enabled] overrides the schedule until its next transition.
  factory SetNightLightMessage({required bool enabled}) = _SetNightLightMessage;

  /// Creates a new [SetNightLightMessage] instance from a map.
  factory SetNightLightMessage.fromJson(Map<String, dynamic> json) =>
      _$SetNightLightMessageFromJson(json);
}
