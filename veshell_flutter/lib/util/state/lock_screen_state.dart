import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../generated/util/state/lock_screen_state.freezed.dart';

final lockScreenStateProvider =
    StateNotifierProvider<LockScreenStateNotifier, LockScreenState>((ref) => LockScreenStateNotifier());

class LockScreenStateNotifier extends StateNotifier<LockScreenState> {
  LockScreenStateNotifier()
      : super(
          const LockScreenState(
            locked: false,
            lock: Object(),
            unlock: Object(),
          ),
        );

  void lock() {
    state = state.copyWith(
      lock: Object(),
      locked: true,
    );
  }

  /// Starts the unlock animation. The Widget must listen to this event.
  void unlock() {
    state = state.copyWith(
      unlock: Object(),
      locked: false,
    );
  }
}

@freezed
class LockScreenState with _$LockScreenState {
  const factory LockScreenState({
    required bool locked,
    required Object lock,
    required Object unlock,
  }) = _LockScreenState;
}
