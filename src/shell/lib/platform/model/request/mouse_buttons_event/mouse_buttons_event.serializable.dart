import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/wayland/model/wl_surface.dart';

part 'mouse_buttons_event.serializable.freezed.dart';
part 'mouse_buttons_event.serializable.g.dart';

/// [MouseButtonsEventRequest]
class MouseButtonsEventRequest extends PlatformRequest {
  /// constructor
  const MouseButtonsEventRequest({
    required MouseButtonsEventMessage super.message,
    super.method = 'mouse_buttons_event',
  });
}

/// Model for [MouseButtonsEventMessage]
@freezed
abstract class MouseButtonsEventMessage
    with _$MouseButtonsEventMessage
    implements PlatformMessage {
  /// Factory
  factory MouseButtonsEventMessage({
    required SurfaceId surfaceId,
    required IList<Button> buttons,
  }) = _MouseButtonsEventMessage;

  /// Creates a new [MouseButtonsEventMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [MouseButtonsEventMessage] instance.
  factory MouseButtonsEventMessage.fromJson(Map<String, dynamic> json) =>
      _$MouseButtonsEventMessageFromJson(json);
}

@freezed
abstract class Button with _$Button {
  factory Button({
    required int button,
    required bool isPressed,
  }) = _Button;

  factory Button.fromJson(Map<String, dynamic> json) => _$ButtonFromJson(json);
}
