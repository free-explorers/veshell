import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/key_press/model/key_press_history.dart';
import 'package:shell/lock_screen/provider/lock_screen.dart';
import 'package:shell/settings/provider/state/show_key_presses_setting.dart';

part 'key_press_recorder.g.dart';

/// How long the visualization stays once every key is released.
const keyPressLinger = Duration(milliseconds: 1600);

/// The recent key presses, for the on-screen visualization.
///
/// Every hardware key event reaches the shell before any client, so the
/// global [HardwareKeyboard] sees the keys typed into clients too. The
/// handler is registered only while an overlay watches it (while
/// `keyboard.showKeyPresses` is on) and the session is unlocked: nothing
/// typed at the lock screen is ever recorded, and locking drops the history.
@riverpod
class KeyPressRecorder extends _$KeyPressRecorder {
  Timer? _hideTimer;

  @override
  KeyPressHistory build() {
    final enabled = ref.watch(showKeyPressesSettingProvider);
    final locked = ref.watch(lockScreenProvider.select((lock) => lock.locked));
    if (!enabled || locked) return const KeyPressHistory();

    final keyboard = HardwareKeyboard.instance;
    bool handle(KeyEvent event) {
      record(event, keyboard.logicalKeysPressed);
      // Only watching: the key goes on to the shell's shortcuts or a client.
      return false;
    }

    keyboard.addHandler(handle);
    ref.onDispose(() {
      keyboard.removeHandler(handle);
      _hideTimer?.cancel();
      _hideTimer = null;
    });
    return const KeyPressHistory();
  }

  /// Applies [event], [pressed] being the logical keys held after it.
  void record(KeyEvent event, Set<LogicalKeyboardKey> pressed) {
    state = state.record(event, pressed);
    _hideTimer?.cancel();
    // Held keys keep it shown; it fades once they are all released.
    if (pressed.isEmpty && state.visible) {
      _hideTimer = Timer(keyPressLinger, () => state = state.hidden());
    }
  }
}
