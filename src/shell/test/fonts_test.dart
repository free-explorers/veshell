import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/provider/state/theme_color_setting.dart';
import 'package:shell/theme/fonts.dart';
import 'package:shell/theme/provider/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CJK ordering follows locale while retaining all system families', () {
    for (final (locale, expected) in const [
      (Locale('en'), 'Noto Sans CJK SC'),
      (Locale('zh'), 'Noto Sans CJK SC'),
      (
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        'Noto Sans CJK TC',
      ),
      (Locale('zh', 'TW'), 'Noto Sans CJK TC'),
      (Locale('zh', 'HK'), 'Noto Sans CJK TC'),
      (Locale('zh', 'MO'), 'Noto Sans CJK TC'),
      (Locale('ja'), 'Noto Sans CJK JP'),
      (Locale('ko'), 'Noto Sans CJK KR'),
    ]) {
      final families = shellFontFallbacks(locale);
      expect(families[4], expected);
      expect(families.toSet(), {
        'Noto Sans',
        'Noto Sans Arabic',
        'Noto Sans Bengali',
        'Noto Sans Devanagari',
        'Noto Sans CJK SC',
        'Noto Sans CJK TC',
        'Noto Sans CJK JP',
        'Noto Sans CJK KR',
      });
      expect(families.length, families.toSet().length);
    }
  });

  test(
    'both themes and tooltips update fonts when the UI language changes',
    () {
      final container = ProviderContainer(
        overrides: [
          themeColorSettingProvider.overrideWith((ref) => Colors.blue),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(veshellThemeProvider, (_, _) {});
      addTearDown(subscription.close);

      for (final locale in const [Locale('ja'), Locale('ko')]) {
        container.read(systemLocalesProvider.notifier).state = [locale];
        final (light, dark) = container.read(veshellThemeProvider);
        for (final theme in [light, dark]) {
          for (final style in [
            ..._styles(theme.textTheme),
            ..._styles(theme.primaryTextTheme),
            theme.tooltipTheme.textStyle!,
          ]) {
            expect(style.fontFamily, 'Roboto');
            expect(style.fontFamilyFallback, shellFontFallbacks(locale));
          }
        }
      }
    },
  );
}

List<TextStyle> _styles(TextTheme theme) => [
  theme.displayLarge!,
  theme.displayMedium!,
  theme.displaySmall!,
  theme.headlineLarge!,
  theme.headlineMedium!,
  theme.headlineSmall!,
  theme.titleLarge!,
  theme.titleMedium!,
  theme.titleSmall!,
  theme.bodyLarge!,
  theme.bodyMedium!,
  theme.bodySmall!,
  theme.labelLarge!,
  theme.labelMedium!,
  theme.labelSmall!,
];
