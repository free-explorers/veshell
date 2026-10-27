import 'package:freezed_annotation/freezed_annotation.dart';

part 'lock_screen_state.freezed.dart';

/// What the lock screen shows, mirrored from the compositor's lock and PAM
/// stacks.
@freezed
abstract class LockScreenState with _$LockScreenState {
  /// Factory
  const factory LockScreenState({
    @Default(false) bool locked,
    @Default('') String userName,
    @Default('') String realName,

    /// The prompt the password stack waits on; null while it has none (the
    /// attempt is being checked, or the stack is restarting).
    String? prompt,

    /// Whether the prompt's answer may be shown while typed.
    @Default(false) bool echo,

    /// An answer was sent and PAM has not settled it yet.
    @Default(false) bool checking,

    /// The last attempt's failure, or a PAM message to show under the field.
    LockScreenNotice? passwordNotice,

    /// Bumped on every failed attempt, so the field can shake each time.
    @Default(0) int failureCount,

    /// The fingerprint stack's latest message; null when it is not running.
    LockScreenNotice? fingerprintNotice,
  }) = _LockScreenState;
}

/// A line of text under the password field.
@freezed
abstract class LockScreenNotice with _$LockScreenNotice {
  /// Factory
  const factory LockScreenNotice({
    /// PAM's own text, or null for the localized "wrong password".
    String? text,
    @Default(false) bool isError,
  }) = _LockScreenNotice;
}
