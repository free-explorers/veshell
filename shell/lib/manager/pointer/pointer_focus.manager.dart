import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/manager/wayland/request/pointer_exit/pointer_exit.model.serializable.dart';
import 'package:shell/manager/wayland/wayland.manager.dart';

part 'pointer_focus.manager.g.dart';

@Riverpod(keepAlive: true)
PointerFocusManager pointerFocusManager(PointerFocusManagerRef ref) =>
    PointerFocusManager(ref);

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
class PointerFocusManager {
  PointerFocusManager(this._ref);
  final Ref _ref;

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

  void exitSurface() {
    _insideSurface = false;
    if (!_maybeDragging) {
      _scheduleExitEvent();
    }
  }

  void enterSurface() {
    _insideSurface = true;
    _pointerExitTimer?.cancel();
  }

  void _scheduleExitEvent() {
    _pointerExitTimer = Timer(
      Duration.zero,
      () => _ref
          .read(waylandManagerProvider.notifier)
          .request(const PointerExitRequest()),
    );
  }
}
