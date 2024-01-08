import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/request/wayland_request.dart';
import 'package:shell/manager/wayland/surface/wl_surface/wl_surface.model.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'touch.model.serializable.freezed.dart';
part 'touch.model.serializable.g.dart';

/// [TouchDownRequest]
class TouchDownRequest extends WaylandRequest {
  /// constructor
  const TouchDownRequest({
    required TouchDownMessage super.message,
    super.method = 'touch_down',
  });
}

/// Model for [TouchDownMessage]
@freezed
class TouchDownMessage with _$TouchDownMessage implements WaylandMessage {
  /// Factory
  factory TouchDownMessage({
    required SurfaceId surfaceId,
    required int touchId,
    required double x,
    required double y,
  }) = _TouchDownMessage;

  /// Creates a new [TouchDownMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [TouchDownMessage] instance.
  factory TouchDownMessage.fromJson(Map<String, dynamic> json) =>
      _$TouchDownMessageFromJson(json);
}

/// [TouchMotionRequest]
class TouchMotionRequest extends WaylandRequest {
  /// constructor
  const TouchMotionRequest({
    required TouchMotionMessage super.message,
    super.method = 'touch_motion',
  });
}

/// Model for [TouchMotionMessage]
@freezed
class TouchMotionMessage with _$TouchMotionMessage implements WaylandMessage {
  /// Factory
  factory TouchMotionMessage({
    required int touchId,
    required double x,
    required double y,
  }) = _TouchMotionMessage;

  /// Creates a new [TouchMotionMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [TouchMotionMessage] instance.
  factory TouchMotionMessage.fromJson(Map<String, dynamic> json) =>
      _$TouchMotionMessageFromJson(json);
}

/// [TouchUpRequest]
class TouchUpRequest extends WaylandRequest {
  /// constructor
  const TouchUpRequest({
    required TouchIdMessage super.message,
    super.method = 'touch_up',
  });
}

/// [TouchCancelRequest]
class TouchCancelRequest extends WaylandRequest {
  /// constructor
  const TouchCancelRequest({
    required TouchIdMessage super.message,
    super.method = 'touch_cancel',
  });
}

/// Model for [TouchIdMessage]
@freezed
class TouchIdMessage with _$TouchIdMessage implements WaylandMessage {
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
