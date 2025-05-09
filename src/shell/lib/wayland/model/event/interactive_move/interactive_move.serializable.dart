import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/meta_window/model/meta_window.serializable.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'interactive_move.serializable.freezed.dart';
part 'interactive_move.serializable.g.dart';

/// Model for InteractiveMoveMessage
@freezed
class InteractiveMoveMessage
    with _$InteractiveMoveMessage
    implements WaylandMessage {
  /// Factory
  factory InteractiveMoveMessage({
    required MetaWindowId metaWindowId,
  }) = _InteractiveMoveMessage;

  factory InteractiveMoveMessage.fromJson(Map<String, dynamic> json) =>
      _$InteractiveMoveMessageFromJson(json);
}
