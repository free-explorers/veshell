import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/model/wl_surface.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'destroy_popup.serializable.freezed.dart';
part 'destroy_popup.serializable.g.dart';

/// Model for DestroyPopupMessage
@freezed
class DestroyPopupMessage with _$DestroyPopupMessage implements WaylandMessage {
  /// Factory
  factory DestroyPopupMessage({
    required SurfaceId surfaceId,
  }) = _DestroyPopupMessage;

  factory DestroyPopupMessage.fromJson(Map<String, dynamic> json) =>
      _$DestroyPopupMessageFromJson(json);
}
