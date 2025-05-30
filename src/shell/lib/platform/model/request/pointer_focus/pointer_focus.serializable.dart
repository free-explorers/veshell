import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/wayland_request.dart';
import 'package:shell/platform/provider/wayland.manager.dart';
import 'package:shell/pointer/model/pointer_focus.serializable.dart';

part 'pointer_focus.serializable.freezed.dart';
part 'pointer_focus.serializable.g.dart';

/// [PointerFocusRequest]
class PointerFocusRequest extends WaylandRequest {
  /// constructor
  const PointerFocusRequest({
    required PointerFocusMessage super.message,
    super.method = 'pointer_focus',
  });
}

/// Model for [PointerFocusMessage]
@freezed
abstract class PointerFocusMessage
    with _$PointerFocusMessage
    implements WaylandMessage {
  /// Factory
  factory PointerFocusMessage({
    required PointerFocus? focus,
  }) = _PointerFocusMessage;

  /// Creates a new [PointerFocusMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [PointerFocusMessage] instance.
  factory PointerFocusMessage.fromJson(Map<String, dynamic> json) =>
      _$PointerFocusMessageFromJson(json);
}
