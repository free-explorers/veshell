import 'package:flutter_test/flutter_test.dart';
import 'package:shell/dev_tools/probe/probe_clock.dart';

Duration ms(int value) => Duration(milliseconds: value);

void main() {
  test('runs with the engine until frozen', () {
    final time = ProbeClockTime();
    expect(time.timeFor(ms(100)), ms(100));
    expect(time.timeFor(ms(116)), ms(116));
    expect(time.isFrozen, isFalse);
  });

  test('frozen, every frame shows the instant it froze at', () {
    final time = ProbeClockTime()..timeFor(ms(100));
    time.freeze();
    expect(time.timeFor(ms(200)), ms(100));
    expect(time.timeFor(ms(300)), ms(100));
  });

  test('a step moves the frozen time by exactly that much', () {
    final time = ProbeClockTime()..timeFor(ms(100));
    time.freeze();
    expect(time.step(ms(50)), ms(150));
    expect(time.timeFor(ms(999)), ms(150));
    time.step(ms(75));
    expect(time.timeFor(ms(1000)), ms(225));
  });

  test('resuming continues from the frozen instant, with no jump', () {
    final time = ProbeClockTime()..timeFor(ms(100));
    time
      ..freeze()
      ..step(ms(50))
      ..resume();
    // The first frame after resuming shows where the time stood…
    expect(time.timeFor(ms(400)), ms(150));
    // …and the engine's time flows on from there.
    expect(time.timeFor(ms(416)), ms(166));
    expect(time.isFrozen, isFalse);
  });

  test('a step without a freeze freezes first', () {
    final time = ProbeClockTime()..timeFor(ms(100));
    expect(time.step(ms(10)), ms(110));
    expect(time.isFrozen, isTrue);
  });

  test('freezing again while resuming keeps the frozen instant', () {
    final time = ProbeClockTime()..timeFor(ms(100));
    time
      ..freeze()
      ..step(ms(20))
      ..resume()
      ..freeze();
    expect(time.timeFor(ms(500)), ms(120));
  });
}
