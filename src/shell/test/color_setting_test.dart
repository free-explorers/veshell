import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/settings/provider/state/theme_color_setting.dart';
import 'package:shell/settings/provider/util/config_directory.dart';
import 'package:shell/settings/provider/util/default_config_directory.dart';
import 'package:shell/shared/util/json_converter/color.dart';

void main() {
  const converter = ColorConverter();

  group('ColorConverter', () {
    test('reads the form it writes, 0xAARRGGBB', () {
      expect(converter.fromJson('0xFF1C2EB7'), const Color(0xFF1C2EB7));
      expect(converter.fromJson('0x801c2eb7'), const Color(0x801C2EB7));
      expect(converter.toJson(const Color(0xFF1C2EB7)), '0xff1c2eb7');
    });

    test('reads 0xRRGGBB and #RRGGBB as opaque colors', () {
      expect(converter.fromJson('0x1C2EB7'), const Color(0xFF1C2EB7));
      expect(converter.fromJson('#1c2eb7'), const Color(0xFF1C2EB7));
    });

    test('refuses anything else', () {
      for (final value in <Object?>[
        4280037047,
        null,
        '',
        '1C2EB7',
        '0x1C2E',
        '0xFF1C2EB7FF',
        '#FF1C2EB7',
        '0xGG1C2EB7',
        '#1C2EB',
      ]) {
        expect(
          () => converter.fromJson(value),
          throwsFormatException,
          reason: '$value',
        );
      }
    });
  });

  group('themeColorSetting', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('theme_color');
    });

    tearDown(() {
      directory.deleteSync(recursive: true);
    });

    Color themeColorFor(String settings) {
      File('${directory.path}/settings.json').writeAsStringSync(settings);
      final container = ProviderContainer(
        overrides: [
          configDirectoryProvider.overrideWithValue(directory),
          defaultConfigDirectoryProvider.overrideWithValue(
            Directory('../../extra/settings/default'),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container.read(themeColorSettingProvider);
    }

    test('follows a valid configured color', () {
      expect(
        themeColorFor('{"theme":{"color":"#1C2EB7"}}'),
        const Color(0xFF1C2EB7),
      );
    });

    test('falls back to the default color on an invalid value', () {
      for (final value in ['4280037047', '"blue"', '[]']) {
        expect(
          themeColorFor('{"theme":{"color":$value}}'),
          themeColorFallback,
          reason: value,
        );
      }
    });

    test('the fallback is the default settings color', () {
      expect(themeColorFor('{}'), themeColorFallback);
    });
  });
}
