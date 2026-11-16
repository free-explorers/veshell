import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'system_tray_activation_token.serializable.freezed.dart';
part 'system_tray_activation_token.serializable.g.dart';

/// `SystemTrayActivationTokenRequest`
///
/// Asks the compositor for a trusted `xdg_activation_v1` token before a tray
/// item is activated. The compositor answers the token; the window the
/// application activates with it is focused and brought into view instead of
/// being read as a demand for attention. An application that cannot take the
/// token activates with one of its own: the compositor grants the item's
/// process that activation for a moment too.
class SystemTrayActivationTokenRequest extends PlatformRequest {
  /// constructor
  const SystemTrayActivationTokenRequest({
    required SystemTrayActivationTokenMessage super.message,
    super.method = 'system_tray_activation_token',
  });
}

/// The tray item the user activated, by its watcher id.
@freezed
sealed class SystemTrayActivationTokenMessage
    with _$SystemTrayActivationTokenMessage
    implements PlatformMessage {
  /// Factory
  factory SystemTrayActivationTokenMessage({required String id}) =
      _SystemTrayActivationTokenMessage;

  factory SystemTrayActivationTokenMessage.fromJson(
    Map<String, dynamic> json,
  ) => _$SystemTrayActivationTokenMessageFromJson(json);
}
