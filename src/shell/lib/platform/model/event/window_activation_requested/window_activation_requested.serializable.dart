import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'window_activation_requested.serializable.freezed.dart';
part 'window_activation_requested.serializable.g.dart';

/// The compositor honored an activation token minted for an invoked
/// notification action and focused the window.
///
/// The compositor cannot select the workspace and tile the window lives in,
/// so the shell brings it into view; without that the window keeps keyboard
/// focus but stays off-screen.
@freezed
sealed class WindowActivationRequestedMessage
    with _$WindowActivationRequestedMessage
    implements PlatformMessage {
  /// Factory
  factory WindowActivationRequestedMessage({required String metaWindowId}) =
      _WindowActivationRequestedMessage;

  factory WindowActivationRequestedMessage.fromJson(
    Map<String, dynamic> json,
  ) => _$WindowActivationRequestedMessageFromJson(json);
}
