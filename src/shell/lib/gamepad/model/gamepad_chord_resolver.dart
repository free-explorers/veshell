import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shell/gamepad/model/gamepad_button.dart';
import 'package:shell/shortcut_manager/model/navigation_intents.dart';

/// Turns gamepad presses into bound intents.
///
/// A press resolves the set of buttons now held against the bindings, like a
/// keyboard chord: `leftShoulder+dpadLeft` fires when the D-pad is pressed
/// while the shoulder is held.
///
/// A chord that is also the start of a longer one (a lone `leftShoulder`,
/// when `leftShoulder+dpadLeft` is bound too) cannot fire on press, or every
/// move would also trigger it. It fires on release instead, provided no other
/// button was pressed meanwhile — the same rule as the lone Super tap that
/// toggles the overview.
///
/// Directional intents repeat while held: once after [repeatDelay], then every
/// [repeatInterval], until a button is pressed or released.
class GamepadChordResolver {
  ///
  GamepadChordResolver({
    required Iterable<(GamepadChord, Intent)> bindings,
    required this.invoke,
    this.repeatDelay = const Duration(milliseconds: 400),
    this.repeatInterval = const Duration(milliseconds: 120),
  }) {
    for (final (chord, intent) in bindings) {
      _intentByChord[chord.key] = intent;
      _chords.add(chord);
    }
  }

  /// Dispatches a resolved intent.
  final void Function(Intent intent) invoke;

  /// How long a directional chord is held before it repeats.
  final Duration repeatDelay;

  /// The pace of the repeats.
  final Duration repeatInterval;

  final _intentByChord = <String, Intent>{};
  final _chords = <GamepadChord>[];
  final _held = <GamepadButton>{};

  /// The intent of a held prefix chord, fired on release when nothing else
  /// was pressed meanwhile.
  Intent? _pendingOnRelease;
  Timer? _repeatTimer;

  /// The buttons currently held.
  Set<GamepadButton> get held => Set.unmodifiable(_held);

  /// Feeds one press or release from the compositor.
  void handle(GamepadButton button, {required bool pressed}) {
    if (pressed) {
      _press(button);
    } else {
      _release(button);
    }
  }

  void _press(GamepadButton button) {
    if (!_held.add(button)) {
      return;
    }
    _stopRepeat();
    // Another button joined: a pending lone tap became a chord.
    _pendingOnRelease = null;

    final chord = GamepadChord(_held);
    final intent = _intentByChord[chord.key];
    if (intent == null) {
      return;
    }
    if (_isPrefixOfLongerChord(chord)) {
      _pendingOnRelease = intent;
      return;
    }
    invoke(intent);
    if (_repeats(intent)) {
      _repeatTimer = Timer(repeatDelay, () {
        _repeatTimer = Timer.periodic(repeatInterval, (_) => invoke(intent));
        invoke(intent);
      });
    }
  }

  void _release(GamepadButton button) {
    if (!_held.remove(button)) {
      return;
    }
    _stopRepeat();
    final pending = _pendingOnRelease;
    _pendingOnRelease = null;
    if (pending != null) {
      invoke(pending);
    }
  }

  /// Forgets every held button without firing anything (the shell is being
  /// torn down, or the bindings changed under a held chord).
  void reset() {
    _stopRepeat();
    _pendingOnRelease = null;
    _held.clear();
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  bool _isPrefixOfLongerChord(GamepadChord chord) => _chords.any(
    (other) =>
        other.buttons.length > chord.buttons.length &&
        other.buttons.containsAll(chord.buttons),
  );

  static bool _repeats(Intent intent) =>
      intent is NavigateIntent || intent is MoveIntent;
}
