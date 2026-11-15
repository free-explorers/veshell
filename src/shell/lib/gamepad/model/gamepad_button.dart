/// A gamepad control, by position, as the compositor reports it.
///
/// The face buttons follow the Linux gamepad API's naming: [south] is A on an
/// Xbox pad, Cross on a PlayStation pad and B on a Nintendo pad. The sticks
/// arrive as digital directions (`leftStickUp`…), already debounced by the
/// compositor.
enum GamepadButton {
  south,
  east,
  north,
  west,
  leftShoulder,
  rightShoulder,
  leftTrigger,
  rightTrigger,
  select,
  start,
  guide,
  leftThumb,
  rightThumb,
  dpadUp,
  dpadDown,
  dpadLeft,
  dpadRight,
  leftStickUp,
  leftStickDown,
  leftStickLeft,
  leftStickRight,
  rightStickUp,
  rightStickDown,
  rightStickLeft,
  rightStickRight;

  /// The button named [name] (the compositor's and the settings' spelling),
  /// or `null` for an unknown name.
  static GamepadButton? tryParse(String name) {
    for (final button in values) {
      if (button.name == name) {
        return button;
      }
    }
    return null;
  }
}

/// A set of gamepad buttons held together, written `leftShoulder+dpadLeft`.
///
/// A chord matches when exactly its buttons are held, whatever the order they
/// were pressed in.
extension type const GamepadChord._(Set<GamepadButton> buttons) {
  /// The chord of [buttons].
  GamepadChord(Iterable<GamepadButton> buttons)
    : this._(Set.unmodifiable(buttons));

  /// Parses `button+button…`; `null` when empty or a name is unknown, so a
  /// typo never turns into a chord that matches something else.
  static GamepadChord? tryParse(String text) {
    final names = text.split('+').map((name) => name.trim());
    final buttons = <GamepadButton>{};
    for (final name in names) {
      final button = GamepadButton.tryParse(name);
      if (button == null) {
        return null;
      }
      buttons.add(button);
    }
    return buttons.isEmpty ? null : GamepadChord(buttons);
  }

  /// A stable key: the same buttons give the same key in any order.
  String get key =>
      (buttons.map((button) => button.index).toList()..sort()).join('+');
}
