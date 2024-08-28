import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/x11_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'x11_properties_changed.serializable.freezed.dart';
part 'x11_properties_changed.serializable.g.dart';

/// Model for X11PropertiesChangedMessage
@freezed
sealed class X11PropertiesChangedMessage
    with _$X11PropertiesChangedMessage
    implements WaylandMessage {
  /// Factory
  factory X11PropertiesChangedMessage({
    required X11SurfaceId x11SurfaceId,
    required String? title,
    required String? windowClass,
    required String? instance,
    required String? startupId,
    required int? pid,
  }) = _X11PropertiesChangedMessage;

  factory X11PropertiesChangedMessage.fromJson(Map<String, dynamic> json) =>
      _$X11PropertiesChangedMessageFromJson(json);
}
