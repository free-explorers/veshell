import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'unregister_view_texture.serializable.freezed.dart';
part 'unregister_view_texture.serializable.g.dart';

/// [UnregisterViewTextureRequest]
class UnregisterViewTextureRequest extends PlatformRequest {
  ///
  const UnregisterViewTextureRequest({
    required UnregisterViewTextureMessage super.message,
    super.method = 'unregister_view_texture',
  });
}

/// Model for [UnregisterViewTextureMessage]
@freezed
abstract class UnregisterViewTextureMessage
    with _$UnregisterViewTextureMessage
    implements PlatformMessage {
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
