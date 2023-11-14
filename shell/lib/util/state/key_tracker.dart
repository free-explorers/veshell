import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../generated/util/state/key_tracker.freezed.dart';

final keyTrackerProvider =
    StateNotifierProvider.family<KeyTrackerNotifier, KeyState, KeyboardKey>((ref, KeyboardKey key) {
  return KeyTrackerNotifier(key);
});

class KeyTrackerNotifier extends StateNotifier<KeyState> {
  KeyTrackerNotifier(KeyboardKey key)
      : super(
          const KeyState(
            isDown: false,
            down: Object(),
            longPress: Object(),
            shortPress: Object(),
            up: Object(),
            longPressTimer: null,
          ),
        );

  void down() {
    if (state.isDown) {
      return;
    }
    assert(state.longPressTimer == null);
    state = state.copyWith(
      isDown: true,
      down: Object(),
      longPressTimer: Timer(
        const Duration(seconds: 1),
        _longPress,
      ),
    );
  }

  void _longPress() {
    state = state.copyWith(
      longPress: Object(),
      longPressTimer: null,
    );
  }

  void up() {
    if (!state.isDown) {
      return;
    }
    if (state.longPressTimer != null) {
      state.longPressTimer!.cancel();
      state = state.copyWith(
        shortPress: Object(),
        longPressTimer: null,
      );
    }

    state = state.copyWith(
      isDown: false,
      up: Object(),
    );
  }
}

@freezed
class KeyState with _$KeyState {
  const factory KeyState({
    required bool isDown,
    required Object down,
    required Object longPress,
    required Object shortPress,
    required Object up,
    required Timer? longPressTimer,
  }) = _KeyState;
}
