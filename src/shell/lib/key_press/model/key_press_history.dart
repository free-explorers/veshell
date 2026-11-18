import 'package:flutter/services.dart';

/// A key pressed with its modifiers (`Ctrl + Shift + T`), or modifiers
/// pressed and released on their own (`Super`).
class KeyChord {
  const KeyChord(this.keys, {this.count = 1});

  /// The labels of the keys, modifiers first.
  final List<String> keys;

  /// How many times in a row the chord was pressed or repeated.
  final int count;

  bool hasKeys(List<String> other) =>
      keys.length == other.length &&
      Iterable<int>.generate(keys.length).every((i) => keys[i] == other[i]);
}

/// What the key press visualization shows: the latest chord only, and the
/// keys held right now.
///
/// Immutable: [record] folds a hardware key event into a new one.
class KeyPressHistory {
  const KeyPressHistory({
    this.chord,
    this.heldModifiers,
    this.pressed = const {},
    this.visible = false,
    this.solePress = false,
  });

  /// The latest chord completed, counting its presses in a row.
  final KeyChord? chord;

  /// The modifiers held for a chord whose key is not pressed yet, shown
  /// instead of [chord] (`Ctrl + Shift`).
  final List<String>? heldModifiers;

  /// The labels of the keys held right now, highlighted where shown.
  final Set<String> pressed;

  /// Whether the visualization is shown. Once hidden after a pause it keeps
  /// its chord so it can fade out; the next press starts afresh.
  final bool visible;

  /// Whether [heldModifiers] went down with no other key in between: released
  /// as is, they become a chord of their own (a lone Super opens the
  /// overview, and is worth showing).
  final bool solePress;

  /// The keys to show, and how many times in a row they were pressed.
  ({List<String> keys, int count})? get shown {
    final held = heldModifiers;
    if (held != null) return (keys: held, count: 1);
    final chord = this.chord;
    if (chord == null) return null;
    return (keys: chord.keys, count: chord.count);
  }

  /// The state once [event] is applied; [pressedKeys] is the set of logical
  /// keys held after it (`HardwareKeyboard.logicalKeysPressed`).
  KeyPressHistory record(KeyEvent event, Set<LogicalKeyboardKey> pressedKeys) {
    final held = modifierLabels(pressedKeys);
    final pressed = {
      for (final key in pressedKeys) modifierLabel(key) ?? keyLabel(key),
    };
    final isModifier = modifierLabel(event.logicalKey) != null;

    if (event is KeyUpEvent) {
      final pendingModifiers = heldModifiers;
      if (isModifier && pendingModifiers != null) {
        if (solePress) {
          return KeyPressHistory(
            chord: _next(chord, pendingModifiers),
            pressed: pressed,
            visible: true,
          );
        }
        // Released unused: back to the latest chord.
        return KeyPressHistory(
          chord: chord,
          pressed: pressed,
          visible: visible,
        );
      }
      return _withPressed(pressed);
    }

    if (isModifier && event is KeyRepeatEvent) return _withPressed(pressed);

    // A press after the visualization was hidden starts afresh.
    final base = visible ? chord : null;

    if (isModifier) {
      return KeyPressHistory(
        chord: base,
        heldModifiers: held,
        pressed: pressed,
        visible: true,
        // Only modifiers held since the first went down, nothing else.
        solePress:
            pressedKeys.length == 1 || (solePress && heldModifiers != null),
      );
    }

    return KeyPressHistory(
      chord: _next(base, [...held, keyLabel(event.logicalKey)]),
      pressed: pressed,
      visible: true,
    );
  }

  /// The same state, hidden.
  KeyPressHistory hidden() => KeyPressHistory(
    chord: chord,
    heldModifiers: heldModifiers,
    pressed: pressed,
    solePress: solePress,
  );

  KeyPressHistory _withPressed(Set<String> pressed) => KeyPressHistory(
    chord: chord,
    heldModifiers: heldModifiers,
    pressed: pressed,
    visible: visible,
    solePress: solePress,
  );

  /// [keys] as the latest chord: counted up when it is [last] again.
  static KeyChord _next(KeyChord? last, List<String> keys) =>
      last != null && last.hasKeys(keys)
      ? KeyChord(keys, count: last.count + 1)
      : KeyChord(keys);
}

final _modifierLabels = <LogicalKeyboardKey, String>{
  LogicalKeyboardKey.control: 'Ctrl',
  LogicalKeyboardKey.controlLeft: 'Ctrl',
  LogicalKeyboardKey.controlRight: 'Ctrl',
  LogicalKeyboardKey.alt: 'Alt',
  LogicalKeyboardKey.altLeft: 'Alt',
  LogicalKeyboardKey.altRight: 'Alt',
  LogicalKeyboardKey.altGraph: 'AltGr',
  LogicalKeyboardKey.shift: 'Shift',
  LogicalKeyboardKey.shiftLeft: 'Shift',
  LogicalKeyboardKey.shiftRight: 'Shift',
  // The compositor reports the logo key as `superKey` or as a meta key,
  // depending on the keymap (see `isSuperKeyPressed`).
  LogicalKeyboardKey.superKey: 'Super',
  LogicalKeyboardKey.meta: 'Super',
  LogicalKeyboardKey.metaLeft: 'Super',
  LogicalKeyboardKey.metaRight: 'Super',
};

/// The display order of the modifiers.
const _modifierOrder = ['Ctrl', 'Alt', 'AltGr', 'Shift', 'Super'];

/// The label of [key] when it is a modifier, `null` otherwise.
String? modifierLabel(LogicalKeyboardKey key) => _modifierLabels[key];

/// The labels of the modifiers among [pressed], in display order.
List<String> modifierLabels(Set<LogicalKeyboardKey> pressed) {
  final labels = {for (final key in pressed) ?_modifierLabels[key]};
  return [
    for (final label in _modifierOrder)
      if (labels.contains(label)) label,
  ];
}

final _keyLabels = <LogicalKeyboardKey, String>{
  LogicalKeyboardKey.arrowUp: '↑',
  LogicalKeyboardKey.arrowDown: '↓',
  LogicalKeyboardKey.arrowLeft: '←',
  LogicalKeyboardKey.arrowRight: '→',
  LogicalKeyboardKey.escape: 'Esc',
  LogicalKeyboardKey.space: 'Space',
  LogicalKeyboardKey.enter: 'Enter',
  LogicalKeyboardKey.numpadEnter: 'Enter',
  LogicalKeyboardKey.backspace: 'Backspace',
  LogicalKeyboardKey.delete: 'Delete',
  LogicalKeyboardKey.tab: 'Tab',
  LogicalKeyboardKey.home: 'Home',
  LogicalKeyboardKey.end: 'End',
  LogicalKeyboardKey.pageUp: 'PgUp',
  LogicalKeyboardKey.pageDown: 'PgDn',
  LogicalKeyboardKey.insert: 'Ins',
};

/// The label of a non-modifier [key], as printed on a keycap.
String keyLabel(LogicalKeyboardKey key) {
  final known = _keyLabels[key];
  if (known != null) return known;
  final label = key.keyLabel;
  if (label.isEmpty) return key.debugName ?? 'Key';
  return label.length == 1 ? label.toUpperCase() : label;
}
