import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'set_brightness.serializable.freezed.dart';
part 'set_brightness.serializable.g.dart';

/// [SetBrightnessRequest]: the Helm's brightness slider.
class SetBrightnessRequest extends PlatformRequest {
  /// constructor
  const SetBrightnessRequest({
    required SetBrightnessMessage super.message,
    super.method = 'set_brightness',
  });
}

/// Model for [SetBrightnessMessage]
@freezed
abstract class SetBrightnessMessage
    with _$SetBrightnessMessage
    implements PlatformMessage {
  /// Factory: [fraction] of full brightness, in `0.0..1.0`. The compositor
  /// keeps the panel from turning off.
  factory SetBrightnessMessage({required double fraction}) =
      _SetBrightnessMessage;

  /// Creates a new [SetBrightnessMessage] instance from a map.
  factory SetBrightnessMessage.fromJson(Map<String, dynamic> json) =>
      _$SetBrightnessMessageFromJson(json);
}
