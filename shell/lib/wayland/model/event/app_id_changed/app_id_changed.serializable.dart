import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'app_id_changed.serializable.freezed.dart';

part 'app_id_changed.serializable.g.dart';

/// Model for AppIdChangedMessage
@freezed
class AppIdChangedMessage
    with _$AppIdChangedMessage
    implements WaylandMessage {
  /// Factory
  factory AppIdChangedMessage({
    required SurfaceId surfaceId,
    required String? appId,
  }) = _AppIdChangedMessage;

  factory AppIdChangedMessage.fromJson(Map<String, dynamic> json) =>
      _$AppIdChangedMessageFromJson(json);
}
