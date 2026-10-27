import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'lock_auth_update.serializable.freezed.dart';
part 'lock_auth_update.serializable.g.dart';

/// The PAM stack a [LockAuthUpdateMessage] comes from.
enum LockAuthSource { password, fingerprint }

/// What a [LockAuthUpdateMessage] reports.
enum LockAuthKind {
  /// PAM waits for an answer; `message` is its prompt ("Password: ").
  prompt,

  /// A PAM information message ("Place your finger on the reader").
  info,

  /// A PAM error message ("Failed to match fingerprint").
  error,

  /// The attempt failed. An empty `message` means the credentials were
  /// rejected; otherwise it is PAM's description of the failure.
  failed,

  /// The stack cannot run (no fingerprint enrolled, reader gone).
  unavailable,
}

/// Progress of one of the lock screen's PAM stacks.
@freezed
sealed class LockAuthUpdateMessage
    with _$LockAuthUpdateMessage
    implements PlatformMessage {
  /// Factory
  factory LockAuthUpdateMessage({
    required LockAuthSource source,
    required LockAuthKind kind,
    required String message,
    required bool echo,
  }) = _LockAuthUpdateMessage;

  factory LockAuthUpdateMessage.fromJson(Map<String, dynamic> json) =>
      _$LockAuthUpdateMessageFromJson(json);
}
