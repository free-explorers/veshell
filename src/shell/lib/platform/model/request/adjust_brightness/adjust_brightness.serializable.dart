import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'adjust_brightness.serializable.freezed.dart';
part 'adjust_brightness.serializable.g.dart';

/// [AdjustBrightnessRequest]
class AdjustBrightnessRequest extends PlatformRequest {
  /// constructor
  const AdjustBrightnessRequest({
    required AdjustBrightnessMessage super.message,
    super.method = 'adjust_brightness',
  });
}

/// Model for [AdjustBrightnessMessage]
@freezed
abstract class AdjustBrightnessMessage
    with _$AdjustBrightnessMessage
    implements PlatformMessage {
  /// Factory
  factory AdjustBrightnessMessage({required double delta}) =
      _AdjustBrightnessMessage;

  /// Creates a new [AdjustBrightnessMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [AdjustBrightnessMessage] instance.
  factory AdjustBrightnessMessage.fromJson(Map<String, dynamic> json) =>
      _$AdjustBrightnessMessageFromJson(json);
}
