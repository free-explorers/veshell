import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screen_cast_consent.serializable.freezed.dart';
part 'screen_cast_consent.serializable.g.dart';

/// Which portal source kind a shareable target belongs to (spec 8.2
/// mapping): outputs are MONITOR sources, windows are WINDOW sources.
enum CaptureSourceKind { outputs, windows }

/// Model for ScreenCastSourceMessage
@freezed
sealed class ScreenCastSourceMessage
    with _$ScreenCastSourceMessage
    implements PlatformMessage {
  /// Factory
  factory ScreenCastSourceMessage({
    required String id,
    required String label,
    required CaptureSourceKind kind,
  }) = _ScreenCastSourceMessage;

  factory ScreenCastSourceMessage.fromJson(Map<String, dynamic> json) =>
      _$ScreenCastSourceMessageFromJson(json);
}

/// Model for ScreenCastConsentMessage
@freezed
sealed class ScreenCastConsentMessage
    with _$ScreenCastConsentMessage
    implements PlatformMessage {
  /// Factory
  factory ScreenCastConsentMessage({
    required String sessionHandle,
    required String requestHandle,
    required int consentToken,
    required String appName,
    required List<ScreenCastSourceMessage> sources,
  }) = _ScreenCastConsentMessage;

  factory ScreenCastConsentMessage.fromJson(Map<String, dynamic> json) =>
      _$ScreenCastConsentMessageFromJson(json);
}
