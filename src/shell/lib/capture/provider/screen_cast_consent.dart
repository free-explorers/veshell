import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/capture/model/screen_cast_consent/screen_cast_consent.serializable.dart';
import 'package:shell/capture/model/screen_cast_consent_decision/screen_cast_consent_decision.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screen_cast_consent.g.dart';

/// State of the trusted screen cast consent picker.
///
/// Kept alive for the whole shell: a portal request may open the picker
/// on the first monitor while another view is being laid out, and the
/// event is lost if the provider is disposed and rebuilt between flows.
@Riverpod(keepAlive: true)
class ScreenCastConsent extends _$ScreenCastConsent {
  @override
  ScreenCastConsentMessage? build() {
    final subscription = ref.watch(platformManagerProvider).listen((next) {
      if (next case final ScreenCastConsentEvent event) {
        state = event.message;
      }
      if (next case final ScreenCastConsentDismissedEvent event) {
        if (state?.consentToken == event.message.consentToken) {
          state = null;
        }
      }
    });
    ref.onDispose(subscription.cancel);

    return null;
  }

  /// The user approved the listed source: the picker closes itself and the
  /// decision travels to the compositor, which validates the choice in
  /// Rust again before anything is authorized.
  void approve(String sourceId) {
    final consent = state;
    if (consent == null) {
      return;
    }
    state = null;
    ref
        .read(platformManagerProvider.notifier)
        .request(
          ScreenCastConsentDecisionRequest(
            message: ScreenCastConsentDecisionMessage(
              sessionHandle: consent.sessionHandle,
              consentToken: consent.consentToken,
              outcome: ScreenCastConsentOutcome.approved,
              sourceId: sourceId,
            ),
          ),
        );
  }

  /// The user dropped the flow.
  void cancel() {
    final consent = state;
    if (consent == null) {
      return;
    }
    state = null;
    ref
        .read(platformManagerProvider.notifier)
        .request(
          ScreenCastConsentDecisionRequest(
            message: ScreenCastConsentDecisionMessage(
              sessionHandle: consent.sessionHandle,
              consentToken: consent.consentToken,
              outcome: ScreenCastConsentOutcome.cancelled,
            ),
          ),
        );
  }
}
