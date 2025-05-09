import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'meta_popup_removed.serializable.freezed.dart';
part 'meta_popup_removed.serializable.g.dart';

/// Model for MetaPopupRemovedMessage
@freezed
sealed class MetaPopupRemovedMessage
    with _$MetaPopupRemovedMessage
    implements WaylandMessage {
  /// Factory
  factory MetaPopupRemovedMessage({
    required String id,
  }) = _MetaPopupRemovedMessage;

  factory MetaPopupRemovedMessage.fromJson(Map<String, dynamic> json) =>
      _$MetaPopupRemovedMessageFromJson(json);
}
