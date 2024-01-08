import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/request/wayland_request.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'mouse_button_event.model.serializable.freezed.dart';
part 'mouse_button_event.model.serializable.g.dart';

/// [MouseButtonEventRequest]
class MouseButtonEventRequest extends WaylandRequest {
  /// constructor
  const MouseButtonEventRequest({
    required MouseButtonEventMessage super.message,
    super.method = 'mouse_button_event',
  });
}

/// Model for [MouseButtonEventMessage]
@freezed
class MouseButtonEventMessage
    with _$MouseButtonEventMessage
    implements WaylandMessage {
  /// Factory
  factory MouseButtonEventMessage({
    required int button,
    required bool isPressed,
  }) = _MouseButtonEventMessage;

  /// Creates a new [MouseButtonEventMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [MouseButtonEventMessage] instance.
  factory MouseButtonEventMessage.fromJson(Map<String, dynamic> json) =>
      _$MouseButtonEventMessageFromJson(json);
}
