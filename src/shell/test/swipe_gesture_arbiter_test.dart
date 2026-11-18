import 'package:flutter/rendering.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/platform/provider/swipe_gesture_arbiter.dart';

void main() {
  group('SwipeGestureArbiter', () {
    final horizontal = Object();
    final vertical = Object();

    test('a clear horizontal gesture goes to the horizontal row', () {
      final arbiter = SwipeGestureArbiter()..addMovement(200, 0);

      expect(arbiter.claim(vertical, Axis.vertical), isFalse);
      expect(arbiter.claim(horizontal, Axis.horizontal), isTrue);
    });

    test('a vertical drift at the start does not steal a horizontal swipe', () {
      // The first sample leans vertical (a hand's usual drift) but the axis is
      // only decided once one direction clearly leads the other.
      final arbiter = SwipeGestureArbiter()..addMovement(5, 30);
      expect(arbiter.claim(vertical, Axis.vertical), isFalse);
      expect(arbiter.claim(horizontal, Axis.horizontal), isFalse);

      arbiter.addMovement(120, 10);
      expect(arbiter.claim(vertical, Axis.vertical), isFalse);
      expect(arbiter.claim(horizontal, Axis.horizontal), isTrue);
    });

    test('a diagonal gesture does not commit until an axis leads', () {
      final arbiter = SwipeGestureArbiter()..addMovement(100, 100);

      expect(arbiter.claim(horizontal, Axis.horizontal), isFalse);
      expect(arbiter.claim(vertical, Axis.vertical), isFalse);
    });

    test('the first owner keeps the gesture when the movement turns', () {
      final arbiter = SwipeGestureArbiter()..addMovement(100, 0);
      expect(arbiter.claim(horizontal, Axis.horizontal), isTrue);

      arbiter.addMovement(0, 500);
      expect(arbiter.claim(horizontal, Axis.horizontal), isTrue);
      expect(arbiter.claim(vertical, Axis.vertical), isFalse);
    });

    test('two containers on the same axis cannot both own a gesture', () {
      final other = Object();
      final arbiter = SwipeGestureArbiter()..addMovement(100, 0);

      expect(arbiter.claim(horizontal, Axis.horizontal), isTrue);
      expect(arbiter.claim(other, Axis.horizontal), isFalse);
    });

    test('begin starts a fresh gesture; end keeps the owner until then', () {
      final arbiter = SwipeGestureArbiter()..addMovement(100, 0);
      expect(arbiter.claim(horizontal, Axis.horizontal), isTrue);

      // A late update stays with the owner ...
      arbiter.end();
      expect(arbiter.claim(vertical, Axis.vertical), isFalse);

      // ... but the next gesture is decided from scratch.
      arbiter
        ..begin()
        ..addMovement(0, 100);
      expect(arbiter.claim(vertical, Axis.vertical), isTrue);
      expect(arbiter.claim(horizontal, Axis.horizontal), isFalse);
    });
  });
}
