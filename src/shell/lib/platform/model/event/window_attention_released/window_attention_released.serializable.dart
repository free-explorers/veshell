import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'window_attention_released.serializable.freezed.dart';
part 'window_attention_released.serializable.g.dart';

/// A window no longer asks for the user's attention (X11
/// `_NET_WM_STATE_DEMANDS_ATTENTION` cleared).
///
/// The shell drops the live notification it synthesized for the matching
/// request.
@freezed
sealed class WindowAttentionReleasedMessage
    with _$WindowAttentionReleasedMessage
    implements PlatformMessage {
  /// Factory
  factory WindowAttentionReleasedMessage({required String metaWindowId}) =
      _WindowAttentionReleasedMessage;

  factory WindowAttentionReleasedMessage.fromJson(
    Map<String, dynamic> json,
  ) => _$WindowAttentionReleasedMessageFromJson(json);
}
