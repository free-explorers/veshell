import 'dart:async';
import 'dart:ui';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/request/pointer_focus/pointer_focus.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';
import 'package:shell/pointer/model/pointer_focus.serializable.dart';

part 'pointer_focus.manager.g.dart';

/// Render origins of surfaces currently laid out by Flutter.
///
/// Flutter is the focus master: when a popup disappears, it needs the owner's
/// rendered origin to send the restored focus without falling back to native
/// X11 coordinates.
class SurfaceRenderOrigins extends Notifier<Map<int, Offset>> {
  @override
  Map<int, Offset> build() => const {};

  void set(int surfaceId, Offset origin) {
    if (state[surfaceId] == origin) {
      return;
    }
    state = {...state, surfaceId: origin};
  }

  void remove(int surfaceId) {
    if (!state.containsKey(surfaceId)) {
      return;
    }
    state = {...state}..remove(surfaceId);
  }
}

final surfaceRenderOriginsProvider =
    NotifierProvider<SurfaceRenderOrigins, Map<int, Offset>>(
      SurfaceRenderOrigins.new,
    );

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
    listenSelf((previous, next) {
      if (previous != next) {
        _notifyWayland();
      }
    });
    return null;
  }

  /// The current focus, exposed to the focus master's popup teardown path.
  PointerFocus? get currentFocus => state;

  Timer? _pointerExitTimer;
  bool _maybeDragging = false;
  bool _insideSurface = false;
  Future<void>? _lastFocusRequest;
  bool _ignoreNullFocusOnce = false;

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

  /// Forgets a surface that is being removed without notifying Rust.
  ///
  /// Popup removal restores focus on the compositor side; a late Flutter exit
  /// or null state from the destroyed popup must not undo that restore.
  /// Restores focus to [fallback] when [removedSurfaceId] was the focused
  /// surface.
  ///
  /// This is the Flutter-side half of popup teardown. The fallback's origin is
  /// its current render-box origin, so the compositor receives the same
  /// coordinate space that hover used.
  /// Clears a potential drag started by the surface being torn down without
  /// scheduling an exit. Popup dismissal can consume the button-up event.
  void resetDrag() {
    _maybeDragging = false;
  }

  void restoreSurface(int removedSurfaceId, PointerFocus fallback) {
    final current = state;
    if (current != null && current.surfaceId != removedSurfaceId) {
      return;
    }
    _insideSurface = true;
    _pointerExitTimer?.cancel();
    _pointerExitTimer = null;
    state = fallback;
  }

  void forgetSurface(int surfaceId) {
    if (state?.surfaceId != surfaceId) {
      return;
    }
    _ignoreNullFocusOnce = true;
    _insideSurface = false;
    _pointerExitTimer?.cancel();
    _pointerExitTimer = null;
    state = null;
  }

  void exitSurface(int surfaceId) {
    // MouseRegion exit events from the surface we just left can arrive after
    // the new surface's enter event. Ignoring an exit that does not match the
    // current focus keeps a MetaWindow <-> popup transition from clearing the
    // focus (and therefore the hover offset) of the surface under the cursor.
    if (state?.surfaceId != surfaceId) {
      return;
    }
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
    _pointerExitTimer = Timer(Duration.zero, () {
      state = null;
    });
  }

  void _notifyWayland() {
    final focus = state;
    if (focus == null && _ignoreNullFocusOnce) {
      // The popup surface disappeared while focused. Rust already restored
      // focus to its owner; do not overwrite that with `focus: null`.
      _ignoreNullFocusOnce = false;
      return;
    }
    if (focus != null) {
      _ignoreNullFocusOnce = false;
    }
    _lastFocusRequest = ref
        .read(platformManagerProvider.notifier)
        .request(
          PointerFocusRequest(message: PointerFocusMessage(focus: focus)),
        );
  }

  /// Waits until the most recently observed focus offset has reached the
  /// compositor.
  ///
  /// A click after a popup self-move must not overtake the pointer-focus
  /// request; otherwise the button press is interpreted with the previous
  /// origin.
  Future<void> flushFocus() async {
    await _lastFocusRequest;
  }
}
