import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'new_toplevel.serializable.freezed.dart';
part 'new_toplevel.serializable.g.dart';

/// Model for NewToplevelMessage
@freezed
sealed class NewToplevelMessage
    with _$NewToplevelMessage
    implements WaylandMessage {
  /// Factory
  factory NewToplevelMessage({
    required SurfaceId surfaceId,
    required int pid,
  }) = _NewToplevelMessage;

  factory NewToplevelMessage.fromJson(Map<String, dynamic> json) =>
      _$NewToplevelMessageFromJson(json);
}
