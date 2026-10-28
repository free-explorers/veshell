import 'package:flutter/services.dart';

/// Whether a Super (logo) key is held.
///
/// The compositor reports it as `superKey` or as one of the meta keys,
/// depending on the keymap.
bool isSuperKeyPressed([HardwareKeyboard? keyboard]) {
  final state = keyboard ?? HardwareKeyboard.instance;
  return state.logicalKeysPressed.contains(LogicalKeyboardKey.superKey) ||
      state.isMetaPressed;
}
