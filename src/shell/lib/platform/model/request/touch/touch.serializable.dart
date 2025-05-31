import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'touch.serializable.freezed.dart';
part 'touch.serializable.g.dart';

/// [TouchDownRequest]
class TouchDownRequest extends PlatformRequest {
  /// constructor
  const TouchDownRequest({
    required TouchDownMessage super.message,
    super.method = 'touch_down',
  });
}

/// Model for [TouchDownMessage]
@freezed
abstract class TouchDownMessage
    with _$TouchDownMessage
    implements PlatformMessage {
  /// Factory
  factory TouchDownMessage({
    required SurfaceId surfaceId,
    required int touchId,
  }) = _TouchDownMessage;

  /// Creates a new [TouchDownMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [TouchDownMessage] instance.
  factory TouchDownMessage.fromJson(Map<String, dynamic> json) =>
      _$TouchDownMessageFromJson(json);
}

/// [TouchMotionRequest]
class TouchMotionRequest extends PlatformRequest {
  /// constructor
  const TouchMotionRequest({
    required TouchMotionMessage super.message,
    super.method = 'touch_motion',
  });
}

/// Model for [TouchMotionMessage]
@freezed
abstract class TouchMotionMessage
    with _$TouchMotionMessage
    implements PlatformMessage {
  /// Factory
  factory TouchMotionMessage({
    required int touchId,
  }) = _TouchMotionMessage;

  /// Creates a new [TouchMotionMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [TouchMotionMessage] instance.
  factory TouchMotionMessage.fromJson(Map<String, dynamic> json) =>
      _$TouchMotionMessageFromJson(json);
}

/// [TouchUpRequest]
class TouchUpRequest extends PlatformRequest {
  /// constructor
  const TouchUpRequest({
    required TouchIdMessage super.message,
    super.method = 'touch_up',
  });
}

/// [TouchCancelRequest]
class TouchCancelRequest extends PlatformRequest {
  /// constructor
  const TouchCancelRequest({
    required TouchIdMessage super.message,
    super.method = 'touch_cancel',
  });
}

/// Model for [TouchIdMessage]
@freezed
abstract class TouchIdMessage with _$TouchIdMessage implements PlatformMessage {
  /// Factory
  factory TouchIdMessage({
    required int touchId,
  }) = _TouchIdMessage;

  /// Creates a new [TouchIdMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [TouchIdMessage] instance.
  factory TouchIdMessage.fromJson(Map<String, dynamic> json) =>
      _$TouchIdMessageFromJson(json);
}
