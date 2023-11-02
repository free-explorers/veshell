import 'package:riverpod_annotation/riverpod_annotation.dart';

part '../generated/util/mouse_button_tracker.g.dart';

@Riverpod(keepAlive: true)
MouseButtonTracker mouseButtonTracker(MouseButtonTrackerRef ref) => MouseButtonTracker();

/// When receiving a pointer event in the Listener widget, we can only have a bitmap of all pressed mouse buttons, and
/// not the button that has been pressed or released. This class tracks changes between such bitmaps and returns the
/// difference in the form of a MouseButtonEvent object.
class MouseButtonTracker {
  int buttons = 0;

  MouseButtonEvent? trackButtonState(int newButtons) {
    if (buttons == newButtons) {
      return null;
    }
    var button = buttons ^ newButtons;
    var state = newButtons & button != 0 ? MouseButtonState.pressed : MouseButtonState.released;
    buttons = newButtons;
    return MouseButtonEvent(button, state);
  }
}

enum MouseButtonState {
  pressed,
  released,
}

class MouseButtonEvent {
  int button;
  MouseButtonState state;

  MouseButtonEvent(this.button, this.state);

  @override
  String toString() {
    return 'MouseButtonEvent{button: $button, state: $state}';
  }
}
