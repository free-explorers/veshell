import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mouse_button_tracker.g.dart';

@Riverpod(keepAlive: true)
MouseButtonTracker mouseButtonTracker(Ref ref) => MouseButtonTracker();

/// When receiving a pointer event in the Listener widget, we can only have a bitmap of all pressed mouse buttons, and
/// not the button that has been pressed or released. This class tracks changes between such bitmaps and returns the
/// difference in the form of a MouseButtonEvent object.
///
/// Button changes must also reach the compositor in the order they happened.
/// Forwarding a press can wait on the pointer focus first, so a release that
/// arrives meanwhile would be compared against a press not tracked yet: it
/// would send nothing, then the press would go out and stay stuck. Every
/// forwarding therefore goes through [serialize].
class MouseButtonTracker {
  int buttons = 0;

  Future<void> _pending = Future.value();

  /// Runs [send] once every previously serialized send has completed, whether
  /// it succeeded or not.
  Future<void> serialize(Future<void> Function() send) {
    final result = _pending.then((_) => send());
    _pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  List<MouseButtonEvent> trackButtonState(int newButtons) {
    if (buttons == newButtons) {
      return [];
    }

    final delta = <MouseButtonEvent>[];

    for (var i = 0; i < 8; i++) {
      final mask = 1 << i;
      if ((buttons & mask) == 0 && (newButtons & mask) != 0) {
        delta.add(MouseButtonEvent(mask, MouseButtonState.pressed));
      } else if ((buttons & mask) != 0 && (newButtons & mask) == 0) {
        delta.add(MouseButtonEvent(mask, MouseButtonState.released));
      }
    }

    buttons = newButtons;
    return delta;
  }
}

enum MouseButtonState { pressed, released }

class MouseButtonEvent {
  MouseButtonEvent(this.button, this.state);

  int button;
  MouseButtonState state;

  @override
  String toString() {
    return 'MouseButtonEvent{button: $button, state: $state}';
  }
}
