import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'window_attention_requested.serializable.freezed.dart';
part 'window_attention_requested.serializable.g.dart';

/// A window asks for the user's attention.
///
/// Emitted for X11 `_NET_WM_STATE_DEMANDS_ATTENTION` and for a Wayland
/// `xdg_activation_v1` request that targets an already existing window. The
/// shell turns it into a notification whose activation brings the window into
/// view; the compositor never focuses or navigates to the window itself.
@freezed
sealed class WindowAttentionRequestedMessage
    with _$WindowAttentionRequestedMessage
    implements PlatformMessage {
  /// Factory
  factory WindowAttentionRequestedMessage({required String metaWindowId}) =
      _WindowAttentionRequestedMessage;

  factory WindowAttentionRequestedMessage.fromJson(
    Map<String, dynamic> json,
  ) => _$WindowAttentionRequestedMessageFromJson(json);
}
