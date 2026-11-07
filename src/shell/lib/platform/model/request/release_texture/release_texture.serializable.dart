import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'release_texture.serializable.freezed.dart';
part 'release_texture.serializable.g.dart';

/// Releases the last frame the compositor kept of a window the shell closed,
/// once its closing has played (see `WindowCloseTransition`).
class ReleaseTextureRequest extends PlatformRequest {
  /// constructor
  const ReleaseTextureRequest({
    required ReleaseTextureMessage super.message,
    super.method = 'release_texture',
  });
}

/// Model for [ReleaseTextureMessage]
@freezed
abstract class ReleaseTextureMessage
    with _$ReleaseTextureMessage
    implements PlatformMessage {
  /// Factory
  factory ReleaseTextureMessage({required int textureId}) =
      _ReleaseTextureMessage;

  /// Creates a new [ReleaseTextureMessage] instance from a map.
  factory ReleaseTextureMessage.fromJson(Map<String, dynamic> json) =>
      _$ReleaseTextureMessageFromJson(json);
}
