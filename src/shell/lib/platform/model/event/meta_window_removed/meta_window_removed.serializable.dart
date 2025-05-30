import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/wayland.manager.dart';

part 'meta_window_removed.serializable.freezed.dart';
part 'meta_window_removed.serializable.g.dart';

/// Model for MetaWindowRemovedMessage
@freezed
sealed class MetaWindowRemovedMessage
    with _$MetaWindowRemovedMessage
    implements WaylandMessage {
  /// Factory
  factory MetaWindowRemovedMessage({
    required String id,
  }) = _MetaWindowRemovedMessage;

  factory MetaWindowRemovedMessage.fromJson(Map<String, dynamic> json) =>
      _$MetaWindowRemovedMessageFromJson(json);
}
