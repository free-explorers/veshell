import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/lock_screen/model/lock_auth_respond/lock_auth_respond.serializable.dart';
import 'package:shell/lock_screen/model/lock_auth_update/lock_auth_update.serializable.dart';
import 'package:shell/lock_screen/model/lock_screen_state/lock_screen_state.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/model/request/platform_request.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'lock_screen.g.dart';

/// Asks the compositor to lock the session.
class LockSessionRequest extends PlatformRequest {
  /// constructor
  const LockSessionRequest({super.method = 'lock_session'});
}

/// Tells the compositor the lock screen is drawn, so a pending suspend may go
/// ahead.
class LockScreenShownRequest extends PlatformRequest {
  /// constructor
  const LockScreenShownRequest({super.method = 'lock_screen_shown'});
}

/// The lock screen's state, mirrored from the compositor.
///
/// The compositor owns the lock and the PAM stacks; this only tracks what to
/// draw and relays the user's answers.
@Riverpod(keepAlive: true)
class LockScreen extends _$LockScreen {
  @override
  LockScreenState build() {
    final subscription = ref.watch(platformManagerProvider).listen(_onEvent);
    ref.onDispose(subscription.cancel);
    return const LockScreenState();
  }

  void _onEvent(PlatformEvent event) {
    switch (event) {
      case LockStateChangedEvent(:final message):
        state = message.locked
            ? LockScreenState(
                locked: true,
                userName: message.userName,
                realName: message.realName,
              )
            : const LockScreenState();
      case LockAuthUpdateEvent(:final message):
        if (state.locked) {
          state = reduceAuthUpdate(state, message);
        }
      default:
        break;
    }
  }

  /// Locks the session.
  Future<void> lock() => ref
      .read(platformManagerProvider.notifier)
      .request(const LockSessionRequest());

  /// Answers the pending prompt with [response].
  Future<void> submit(String response) async {
    if (!state.locked || state.checking) return;
    state = state.copyWith(checking: true, prompt: null, passwordNotice: null);
    await ref
        .read(platformManagerProvider.notifier)
        .request(
          LockAuthRespondRequest(
            message: LockAuthRespondMessage(response: response),
          ),
        );
  }

  /// Reports the lock screen drawn.
  Future<void> shown() => ref
      .read(platformManagerProvider.notifier)
      .request(const LockScreenShownRequest());
}

/// Applies one PAM update to the lock screen state.
@visibleForTesting
LockScreenState reduceAuthUpdate(
  LockScreenState state,
  LockAuthUpdateMessage update,
) {
  switch (update.source) {
    case LockAuthSource.password:
      return switch (update.kind) {
        LockAuthKind.prompt => state.copyWith(
          prompt: update.message,
          echo: update.echo,
          checking: false,
        ),
        LockAuthKind.info => state.copyWith(
          passwordNotice: LockScreenNotice(text: update.message),
        ),
        LockAuthKind.error => state.copyWith(
          passwordNotice: LockScreenNotice(text: update.message, isError: true),
        ),
        LockAuthKind.failed => state.copyWith(
          checking: false,
          failureCount: state.failureCount + 1,
          // Keep a PAM error that explains the failure (an account locked by
          // faillock) over the generic text.
          passwordNotice: state.passwordNotice?.isError == true
              ? state.passwordNotice
              : LockScreenNotice(
                  text: update.message.isEmpty ? null : update.message,
                  isError: true,
                ),
        ),
        LockAuthKind.unavailable => state,
      };
    case LockAuthSource.fingerprint:
      return switch (update.kind) {
        LockAuthKind.info => state.copyWith(
          fingerprintNotice: LockScreenNotice(text: update.message),
        ),
        LockAuthKind.error || LockAuthKind.failed => state.copyWith(
          fingerprintNotice: LockScreenNotice(
            text: update.message,
            isError: true,
          ),
        ),
        LockAuthKind.unavailable => state.copyWith(fingerprintNotice: null),
        LockAuthKind.prompt => state,
      };
  }
}
