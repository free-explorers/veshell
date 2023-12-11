import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'interactive_resize.model.serializable.freezed.dart';
part 'interactive_resize.model.serializable.g.dart';

/// Model for InteractiveResizeMessage
@freezed
class InteractiveResizeMessage
    with _$InteractiveResizeMessage
    implements WaylandMessage {
  /// Factory
  factory InteractiveResizeMessage({
    required int surfaceId,
    required int edge,
  }) = _InteractiveResizeMessage;

  factory InteractiveResizeMessage.fromJson(Map<String, dynamic> json) =>
      _$InteractiveResizeMessageFromJson(json);
}
