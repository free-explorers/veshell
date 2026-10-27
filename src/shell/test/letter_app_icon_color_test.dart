import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/application/widget/letter_app_icon.dart';

double _hueDistance(double a, double b) {
  final distance = (a - b).abs() % 360;
  return distance > 180 ? 360 - distance : distance;
}

void main() {
  const titles = ['Firefox', 'Files', 'GIMP', 'Alacritty', 'Spotify', 'Code'];

  test('badges move toward the primary hue', () {
    const primary = Color(0xFF3F51B5);
    final primaryHue = HSLColor.fromColor(primary).hue;
    for (final title in titles) {
      final tinted = HSLColor.fromColor(letterIconColor(title, primary)).hue;
      final untinted = HSLColor.fromColor(
        letterIconColor(title, const Color(0xFF808080)),
      ).hue;
      expect(
        _hueDistance(tinted, primaryHue),
        lessThanOrEqualTo(_hueDistance(untinted, primaryHue) + 1),
        reason: title,
      );
      // At most 60% of the way around: 108° from the primary.
      expect(_hueDistance(tinted, primaryHue), lessThanOrEqualTo(109));
    }
  });

  test('neighbouring apps keep different colours', () {
    const primary = Color(0xFF6750A4);
    final colors = {
      for (final title in titles) letterIconColor(title, primary),
    };
    expect(colors.length, titles.length);
  });

  test('the colour is stable for a title', () {
    const primary = Color(0xFF00897B);
    expect(
      letterIconColor('Firefox', primary),
      letterIconColor('Firefox', primary),
    );
  });
}
