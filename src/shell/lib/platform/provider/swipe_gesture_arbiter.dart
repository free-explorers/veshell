import 'package:flutter/rendering.dart' show Axis;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/platform/model/event/platform_event.serializable.dart';
import 'package:shell/platform/provider/platform_manager.dart';

part 'swipe_gesture_arbiter.g.dart';

/// Decides which container follows a three-finger swipe.
///
/// Every mounted component listens to the same compositor stream, and libinput
/// does not constrain a swipe to an axis: a diagonal or jittery gesture can
/// look horizontal on one update and vertical on the next. Without a single
/// owner, the screen's workspace row and the selected workspace's tile row
/// would both scroll within one physical gesture.
///
/// The first container whose axis matches the gesture's cumulative movement
/// owns it until the next `gesture_swipe_begin`. Claiming by cumulative travel,
/// rather than by the first update, keeps one noisy sample from handing the
/// gesture to the wrong axis.
class SwipeGestureArbiter {
  /// How far one axis must lead the other before the gesture commits, in the
  /// same normalized units as the compositor's swipe deltas (roughly 1 mm).
  ///
  /// Using the lead rather than the first non-zero update is what makes a
  /// horizontal swipe reliable: a hand usually drifts vertically a little
  /// before the horizontal travel develops, and that drift must not hand the
  /// gesture to the workspace row.
  static const _commitLead = 40.0;

  double _travelX = 0;
  double _travelY = 0;
  Object? _owner;

  /// Forgets the previous gesture; called on `gesture_swipe_begin`.
  void begin() {
    _travelX = 0;
    _travelY = 0;
    _owner = null;
  }

  /// Drops the movement once the gesture ends. The owner is kept until the
  /// next [begin] so an update arriving after the end cannot be claimed by the
  /// other container.
  void end() {
    _travelX = 0;
    _travelY = 0;
  }

  /// Records one update's movement for the direction decision.
  void addMovement(double dx, double dy) {
    _travelX += dx;
    _travelY += dy;
  }

  /// Lets [owner] follow the gesture when the gesture is moving along [axis].
  ///
  /// The first caller to match wins for the whole gesture; later callers are
  /// rejected even when they have the same axis, so two rows can never move
  /// together.
  bool claim(Object owner, Axis axis) {
    final current = _owner;
    if (current != null) {
      return identical(current, owner);
    }
    final horizontal = _travelX.abs();
    final vertical = _travelY.abs();
    if ((horizontal - vertical).abs() < _commitLead) {
      return false;
    }
    final dominant = horizontal > vertical ? Axis.horizontal : Axis.vertical;
    if (dominant != axis) {
      return false;
    }
    _owner = owner;
    return true;
  }
}

/// The process-wide swipe arbiter, reset by every three-finger gesture.
@Riverpod(keepAlive: true)
SwipeGestureArbiter swipeGestureArbiter(Ref ref) {
  final arbiter = SwipeGestureArbiter();
  final subscription = ref.watch(platformManagerProvider).listen((event) {
    if (event is GestureSwipeBeginEvent) {
      arbiter.begin();
    } else if (event is GestureSwipeUpdateEvent) {
      arbiter.addMovement(event.message.deltaX, event.message.deltaY);
    } else if (event is GestureSwipeEndEvent) {
      arbiter.end();
    }
  });
  ref.onDispose(subscription.cancel);
  return arbiter;
}
