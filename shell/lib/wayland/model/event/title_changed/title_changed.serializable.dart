import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'title_changed.serializable.freezed.dart';

part 'title_changed.serializable.g.dart';

/// Model for TitleChangedMessage
@freezed
class TitleChangedMessage
    with _$TitleChangedMessage
    implements WaylandMessage {
  /// Factory
  factory TitleChangedMessage({
    required SurfaceId surfaceId,
    required String? title,
  }) = _TitleChangedMessage;

  factory TitleChangedMessage.fromJson(Map<String, dynamic> json) =>
      _$TitleChangedMessageFromJson(json);
}
