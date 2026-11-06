import 'package:flutter_test/flutter_test.dart';
import 'package:shell/settings/provider/state/animation_speed_setting.dart';

void main() {
  test('a stored speed is kept as is within its range', () {
    expect(parseAnimationSpeed(1), 1);
    expect(parseAnimationSpeed(0.5), 0.5);
    expect(parseAnimationSpeed(2), 2);
  });

  test('a speed out of range is brought back to it', () {
    expect(parseAnimationSpeed(0.001), minAnimationSpeed);
    expect(parseAnimationSpeed(100), maxAnimationSpeed);
  });

  test('anything but a positive number plays animations as designed', () {
    expect(parseAnimationSpeed(null), animationSpeedFallback);
    expect(parseAnimationSpeed('fast'), animationSpeedFallback);
    expect(parseAnimationSpeed(0), animationSpeedFallback);
    expect(parseAnimationSpeed(-1), animationSpeedFallback);
    expect(parseAnimationSpeed(double.nan), animationSpeedFallback);
    expect(parseAnimationSpeed(double.infinity), animationSpeedFallback);
  });

  test('half speed makes animations last twice as long', () {
    expect(timeDilationForAnimationSpeed(0.5), 2);
    expect(timeDilationForAnimationSpeed(0.05), closeTo(20, 1e-9));
    expect(timeDilationForAnimationSpeed(2), 0.5);
  });
}
