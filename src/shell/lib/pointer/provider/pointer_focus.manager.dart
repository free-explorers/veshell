import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/request/pointer_focus/pointer_focus.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/pointer/model/pointer_focus.serializable.dart';

part 'pointer_focus.manager.g.dart';

/// The problem:
/// When moving the pointer between 2 MouseRegions, one would trigger an exit event, and the other one an enter event.
/// Let's suppose we have a window and a popup. The pointer exits the window surface and enters the popup surface.
/// When the pointer exits the window surface, this event is propagated to the window and it happens to decide to close
/// the popup even though we moved the pointer on the popup.
///
/// The solution:
/// Don't send the exit event right away. See if an enter event is generated just after.
/// We schedule a asynchronous task for sending an exit event, but if an enter event happens before the next event loop
/// iteration, we cancel the currently scheduled task, thus the exit event will no longer be sent.
@Riverpod(keepAlive: true)
class PointerFocusManager extends _$PointerFocusManager {
  @override
  PointerFocus? build() {
    listenSelf(
      (previous, next) {
        if (previous != next) {
          _notifyWayland();
        }
      },
    );
    return null;
  }

  Timer? _pointerExitTimer;
  bool _maybeDragging = false;
  bool _insideSurface = false;

  void startPotentialDrag() {
    _maybeDragging = true;
  }

  void stopPotentialDrag() {
    _maybeDragging = false;
    if (!_insideSurface) {
      _scheduleExitEvent();
    }
  }

  void hoverSurface(PointerFocus focus) {
    // While a pointer button is held, Flutter re-uses the hit-test path
    // captured on pointer down, so the surface that received the press keeps
    // reporting moves even after the pointer leaves it. The mouse tracker
    // (which re-runs the hit test on every move) is what reports the surface
    // actually under the cursor, through `enterSurface`. Keep that one: it is
    // what lets a native drag-and-drop reach a drop target in another window.
    // The pressed surface is not lost — Smithay's implicit click grab keeps
    // routing plain presses and drag motions to it until the button is
    // released.
    final focusedSurfaceId = state?.surfaceId;
    if (_maybeDragging &&
        focusedSurfaceId != null &&
        focusedSurfaceId != focus.surfaceId) {
      return;
    }
    state = focus;
  }

  void exitSurface() {
    _insideSurface = false;
    if (!_maybeDragging) {
      _scheduleExitEvent();
    }
  }

  void enterSurface(PointerFocus focus) {
    state = focus;
    _insideSurface = true;
    _pointerExitTimer?.cancel();
  }

  void _scheduleExitEvent() {
    _pointerExitTimer = Timer(
      Duration.zero,
      () {
        state = null;
      },
    );
  }

  void _notifyWayland() {
    ref.read(platformManagerProvider.notifier).request(
          PointerFocusRequest(message: PointerFocusMessage(focus: state)),
        );
  }
}
