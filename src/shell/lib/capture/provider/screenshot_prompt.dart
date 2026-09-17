import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/capture/model/screenshot_prompt/screenshot_prompt.serializable.dart';
import 'package:shell/capture/model/screenshot_prompt_decision/screenshot_prompt_decision.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'screenshot_prompt.g.dart';

/// State of the trusted screenshot/color-pick prompt (capture
/// specification section 8.4). Dismissal uses the same token-keyed
/// dismiss event as the screen cast picker.
@riverpod
class ScreenshotPrompt extends _$ScreenshotPrompt {
  @override
  ScreenshotPromptMessage? build() {
    ref.watch(platformManagerProvider).listen((next) {
      if (next case final ScreenshotPromptEvent event) {
        state = event.message;
      }
      if (next case final ScreenCastConsentDismissedEvent event) {
        if (state?.consentToken == event.message.consentToken) {
          state = null;
        }
      }
    });

    return null;
  }

  /// The user allowed the request: the prompt closes itself and the
  /// decision travels to the compositor, which takes the pixels.
  void approve() {
    final prompt = state;
    if (prompt == null) {
      return;
    }
    state = null;
    ref
        .read(platformManagerProvider.notifier)
        .request(
          ScreenshotPromptDecisionRequest(
            message: ScreenshotPromptDecisionMessage(
              consentToken: prompt.consentToken,
              outcome: ScreenshotPromptDecisionOutcome.approved,
            ),
          ),
        );
  }

  /// The user dropped the flow.
  void cancel() {
    final prompt = state;
    if (prompt == null) {
      return;
    }
    state = null;
    ref
        .read(platformManagerProvider.notifier)
        .request(
          ScreenshotPromptDecisionRequest(
            message: ScreenshotPromptDecisionMessage(
              consentToken: prompt.consentToken,
              outcome: ScreenshotPromptDecisionOutcome.cancelled,
            ),
          ),
        );
  }
}
