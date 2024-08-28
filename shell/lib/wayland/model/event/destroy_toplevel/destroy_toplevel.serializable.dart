import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'destroy_toplevel.serializable.freezed.dart';

part 'destroy_toplevel.serializable.g.dart';

/// Model for DestroyToplevelMessage
@freezed
class DestroyToplevelMessage
    with _$DestroyToplevelMessage
    implements WaylandMessage {
  /// Factory
  factory DestroyToplevelMessage({
    required SurfaceId surfaceId,
  }) = _DestroyToplevelMessage;

  factory DestroyToplevelMessage.fromJson(Map<String, dynamic> json) =>
      _$DestroyToplevelMessageFromJson(json);
}
