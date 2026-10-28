import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/monitor/util/scale_recommendation.dart';

void main() {
  group('exactScales', () {
    test('lists the quarters that divide the resolution', () {
      expect(exactScales(const Size(2560, 1440)), [1, 1.25, 2, 2.5]);
      expect(exactScales(const Size(1920, 1080)), [1, 1.25, 1.5, 2, 2.5, 3]);
      // A Framework 13: only whole scales divide it.
      expect(exactScales(const Size(2256, 1504)), [1, 2]);
    });

    test('1.2 is not offered, even where it divides', () {
      // 1920 / 1.2 = 1600: exact, but not a quarter (see the library doc).
      expect(exactScales(const Size(1920, 1080)), isNot(contains(1.2)));
    });
  });

  group('recommendedScale', () {
    test('an external 27-inch 1440p monitor needs no scaling', () {
      expect(
        recommendedScale(
          const Size(2560, 1440),
          const Size(597, 336),
          builtIn: false,
        ),
        1,
      );
    });

    test('a 32-inch 4K monitor prefers the exact 1.25', () {
      expect(
        recommendedScale(
          const Size(3840, 2160),
          const Size(697, 392),
          builtIn: false,
        ),
        1.25,
      );
    });

    test('a 27-inch 4K monitor gets 1.5', () {
      expect(
        recommendedScale(
          const Size(3840, 2160),
          const Size(597, 336),
          builtIn: false,
        ),
        1.5,
      );
    });

    test('a 14-inch 1440p laptop panel gets 1.5', () {
      expect(
        recommendedScale(
          const Size(2560, 1440),
          const Size(310, 174),
          builtIn: true,
        ),
        1.5,
      );
    });

    test('a Framework 13 gets 1.5, though only 1 and 2 are exact', () {
      expect(
        recommendedScale(
          const Size(2256, 1504),
          const Size(285, 190),
          builtIn: true,
        ),
        1.5,
      );
    });

    test('an unknown or impossible physical size gives no recommendation', () {
      for (final size in const [Size.zero, Size(16, 9), Size(160, 90)]) {
        expect(
          recommendedScale(const Size(2560, 1440), size, builtIn: false),
          isNull,
          reason: '$size',
        );
      }
    });
  });

  test('built-in panels are recognized by their connector', () {
    expect(isBuiltInConnector('eDP-1'), isTrue);
    expect(isBuiltInConnector('LVDS-1'), isTrue);
    expect(isBuiltInConnector('DP-2'), isFalse);
    expect(isBuiltInConnector('HDMI-A-1'), isFalse);
  });

  test('scales are formatted without trailing zeros, in the locale', () {
    expect(formatScale(1, '.'), '1');
    expect(formatScale(1.25, '.'), '1.25');
    expect(formatScale(2.5, ','), '2,5');
  });
}
