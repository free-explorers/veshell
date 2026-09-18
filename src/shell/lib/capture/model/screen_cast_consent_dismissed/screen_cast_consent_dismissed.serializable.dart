import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screen_cast_consent_dismissed.serializable.freezed.dart';
part 'screen_cast_consent_dismissed.serializable.g.dart';

/// Model for ScreenCastConsentDismissedMessage
///
/// The compositor decides when a picker leaves the screen; the token binds
/// the dismissal to the consent flow it owns.
@freezed
sealed class ScreenCastConsentDismissedMessage
    with _$ScreenCastConsentDismissedMessage
    implements PlatformMessage {
  /// Factory
  factory ScreenCastConsentDismissedMessage({
    required int consentToken,
  }) = _ScreenCastConsentDismissedMessage;

  factory ScreenCastConsentDismissedMessage.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$ScreenCastConsentDismissedMessageFromJson(json);
}
