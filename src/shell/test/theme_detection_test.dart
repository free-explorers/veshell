import 'package:flutter_test/flutter_test.dart';
import 'package:shell/settings/provider/util/theme_detection.dart';

void main() {
  group('chooseIconTheme', () {
    test('uses an installed configured theme', () {
      expect(
        chooseIconTheme(
          {'breeze', 'Adwaita', 'hicolor'},
          configured: 'Adwaita',
          systemTheme: 'breeze',
        ),
        'Adwaita',
      );
    });

    test('matches configured theme names case-insensitively', () {
      expect(
        chooseIconTheme({'breeze', 'Adwaita'}, configured: 'ADWAITA'),
        'Adwaita',
      );
      expect(
        chooseIconTheme({'breeze', 'Adwaita'}, configured: 'Breeze'),
        'breeze',
      );
    });

    test('ignores a configured theme that is not installed', () {
      expect(
        chooseIconTheme(
          {'breeze', 'Adwaita'},
          configured: 'missing',
          systemTheme: 'Adwaita',
        ),
        'Adwaita',
      );
    });

    test('prefers the desktop theme when no override is configured', () {
      expect(
        chooseIconTheme({
          'breeze',
          'Adwaita',
          'hicolor',
        }, systemTheme: 'Adwaita'),
        'Adwaita',
      );
    });

    test('prefers Breeze over Adwaita without a desktop preference', () {
      expect(chooseIconTheme({'Adwaita', 'breeze', 'hicolor'}), 'breeze');
    });

    test('falls back to hicolor when nothing else is installed', () {
      expect(chooseIconTheme({'hicolor'}), 'hicolor');
      expect(chooseIconTheme(const {}), 'hicolor');
    });

    test('ignores cursor themes', () {
      expect(chooseIconTheme({'Adwaita', 'breeze_cursors'}), 'Adwaita');
    });
  });

  group('chooseGtkTheme', () {
    test('uses an installed configured theme', () {
      expect(
        chooseGtkTheme(
          {'Adwaita', 'Breeze'},
          configured: 'Breeze',
          systemTheme: 'Adwaita',
        ),
        'Breeze',
      );
    });

    test('falls back to the preferred installed theme', () {
      expect(chooseGtkTheme({'Breeze', 'Adwaita'}), 'Adwaita');
    });
  });

  test('withDetectedThemeDefaults fills only missing values', () {
    final detected = withDetectedThemeDefaults(
      {
        'theme': {'color': '0xFF006888'},
      },
      iconTheme: 'breeze',
      gtkTheme: 'Adwaita-dark',
    );

    expect(detected['theme'], {
      'color': '0xFF006888',
      'iconTheme': 'breeze',
      'gtkTheme': 'Adwaita-dark',
    });

    final overridden = withDetectedThemeDefaults(
      {
        'theme': {'color': '0xFF006888', 'iconTheme': 'custom'},
      },
      iconTheme: 'breeze',
      gtkTheme: 'Adwaita-dark',
    );

    expect(overridden['theme'], {
      'color': '0xFF006888',
      'iconTheme': 'custom',
      'gtkTheme': 'Adwaita-dark',
    });
  });
}
