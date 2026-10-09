import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shell/window/provider/window_manager/matching_utils.dart';

void main() {
  group('matchesOutputSize', () {
    test('matches an exact monitor size', () {
      expect(
        matchesOutputSize(const Size(1920, 1080), const [Size(1920, 1080)]),
        isTrue,
      );
    });

    test('matches within the rounding tolerance', () {
      expect(
        matchesOutputSize(const Size(1919.5, 1080.5), const [Size(1920, 1080)]),
        isTrue,
      );
    });

    test('rejects a size that differs beyond the tolerance', () {
      expect(
        matchesOutputSize(const Size(1918, 1080), const [Size(1920, 1080)]),
        isFalse,
      );
    });

    test('matches when any monitor in the set has the size', () {
      expect(
        matchesOutputSize(
          const Size(3840, 2160),
          const [Size(1920, 1080), Size(3840, 2160)],
        ),
        isTrue,
      );
    });

    test('rejects a same-area size with a different aspect ratio', () {
      expect(
        matchesOutputSize(const Size(1080, 1920), const [Size(1920, 1080)]),
        isFalse,
      );
    });

    test('never matches an unknown or empty window size', () {
      expect(matchesOutputSize(null, const [Size(1920, 1080)]), isFalse);
      expect(matchesOutputSize(Size.zero, const [Size(1920, 1080)]), isFalse);
      expect(
        matchesOutputSize(const Size(-1, 1080), const [Size(1920, 1080)]),
        isFalse,
      );
    });

    test('ignores non-positive monitor sizes', () {
      expect(
        matchesOutputSize(Size.zero, const [Size.zero, Size(1920, 1080)]),
        isFalse,
      );
      expect(matchesOutputSize(Size.zero, const [Size.zero]), isFalse);
    });
  });
}
