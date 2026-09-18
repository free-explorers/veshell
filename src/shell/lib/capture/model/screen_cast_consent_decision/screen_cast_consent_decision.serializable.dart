import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screen_cast_consent_decision.serializable.freezed.dart';
part 'screen_cast_consent_decision.serializable.g.dart';

/// [ScreenCastConsentDecisionRequest]
class ScreenCastConsentDecisionRequest extends PlatformRequest {
  /// constructor
  const ScreenCastConsentDecisionRequest({
    required ScreenCastConsentDecisionMessage super.message,
    super.method = 'screen_cast_consent_decision',
  });
}

/// Model for [ScreenCastConsentDecisionMessage]
@freezed
sealed class ScreenCastConsentDecisionMessage
    with _$ScreenCastConsentDecisionMessage
    implements PlatformMessage {
  /// Factory
  factory ScreenCastConsentDecisionMessage({
    required String sessionHandle,
    required int consentToken,
    required ScreenCastConsentOutcome outcome,
    String? sourceId,
  }) = _ScreenCastConsentDecisionMessage;

  factory ScreenCastConsentDecisionMessage.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$ScreenCastConsentDecisionMessageFromJson(json);
}

/// What the user decided in the consent picker.
enum ScreenCastConsentOutcome {
  /// The user approved the listed source.
  approved,

  /// The user dropped the flow.
  cancelled;
}
