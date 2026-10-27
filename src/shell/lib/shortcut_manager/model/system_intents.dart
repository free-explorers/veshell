import 'package:material_ui/material_ui.dart';

/// An intent to increaseVolume
class IncreaseVolume extends Intent {
  ///
  const IncreaseVolume();
}

/// An intent to decreaseVolume
class DecreaseVolume extends Intent {
  ///
  const DecreaseVolume();
}

/// An intent to toggleMute
class ToggleMute extends Intent {
  ///
  const ToggleMute();
}

/// An intent to increaseBrightness
class IncreaseBrightness extends Intent {
  ///
  const IncreaseBrightness();
}

/// An intent to decreaseBrightness
class DecreaseBrightness extends Intent {
  ///
  const DecreaseBrightness();
}

/// An intent to toggle the active keyboard layout
class ToggleKeyboardLayout extends Intent {
  ///
  const ToggleKeyboardLayout();
}

/// An intent to lock the session
class LockSessionIntent extends Intent {
  ///
  const LockSessionIntent();
}
