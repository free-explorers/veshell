import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/file_chooser/model/file_chooser_decision/file_chooser_decision.serializable.dart';
import 'package:shell/file_chooser/model/file_chooser_request/file_chooser_request.serializable.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'file_chooser_request.g.dart';

/// State of the trusted file chooser (portal OpenFile/SaveFile/SaveFiles).
///
/// Kept alive for the whole shell so a request that arrives before the
/// hosting view rebuilds is never dropped. Dismissal reuses the same
/// token-keyed dismiss event as the capture prompts.
@Riverpod(keepAlive: true)
class FileChooserRequest extends _$FileChooserRequest {
  @override
  FileChooserRequestMessage? build() {
    final subscription = ref.watch(platformManagerProvider).listen((next) {
      if (next case final FileChooserRequestEvent event) {
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

  /// The user confirmed the selection: the dialog closes itself and the
  /// decision travels to the compositor, which completes the portal request.
  void approve(List<String> uris) {
    final request = state;
    if (request == null) {
      return;
    }
    state = null;
    ref
        .read(platformManagerProvider.notifier)
        .request(
          FileChooserDecisionRequest(
            message: FileChooserDecisionMessage(
              consentToken: request.consentToken,
              outcome: FileChooserDecisionOutcome.approved,
              uris: uris,
            ),
          ),
        );
  }

  /// The user dropped the flow.
  void cancel() {
    final request = state;
    if (request == null) {
      return;
    }
    state = null;
    ref
        .read(platformManagerProvider.notifier)
        .request(
          FileChooserDecisionRequest(
            message: FileChooserDecisionMessage(
              consentToken: request.consentToken,
              outcome: FileChooserDecisionOutcome.cancelled,
            ),
          ),
        );
  }
}
