import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/wayland/provider/request/wayland_request.dart';
import 'package:shell/wayland/provider/wayland.manager.dart';

part 'unregister_view_texture.serializable.freezed.dart';
part 'unregister_view_texture.serializable.g.dart';

/// [UnregisterViewTextureRequest]
class UnregisterViewTextureRequest extends WaylandRequest {
  ///
  const UnregisterViewTextureRequest({
    required UnregisterViewTextureMessage super.message,
    super.method = 'unregister_view_texture',
  });
}

/// Model for [UnregisterViewTextureMessage]
@freezed
class UnregisterViewTextureMessage
    with _$UnregisterViewTextureMessage
    implements WaylandMessage {
  /// Factory
  factory UnregisterViewTextureMessage({
    required int textureId,
  }) = _UnregisterViewTextureMessage;

  /// Creates a new [UnregisterViewTextureMessage] instance from a map.
  ///
  /// This constructor is used by the `json_serializable` package to
  /// deserialize JSON data into a [UnregisterViewTextureMessage] instance.
  factory UnregisterViewTextureMessage.fromJson(Map<String, dynamic> json) =>
      _$UnregisterViewTextureMessageFromJson(json);
}
