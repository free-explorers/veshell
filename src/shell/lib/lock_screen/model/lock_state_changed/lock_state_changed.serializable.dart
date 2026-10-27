import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'lock_state_changed.serializable.freezed.dart';
part 'lock_state_changed.serializable.g.dart';

/// The compositor locked or unlocked the session.
///
/// The compositor owns the lock (see `src/embedder/lock/`): the shell only
/// draws the lock screen while [locked] is true. [userName] is the login the
/// lock screen authenticates, [realName] the name shown to the user.
@freezed
sealed class LockStateChangedMessage
    with _$LockStateChangedMessage
    implements PlatformMessage {
  /// Factory
  factory LockStateChangedMessage({
    required bool locked,
    required String userName,
    required String realName,
  }) = _LockStateChangedMessage;

  factory LockStateChangedMessage.fromJson(Map<String, dynamic> json) =>
      _$LockStateChangedMessageFromJson(json);
}
