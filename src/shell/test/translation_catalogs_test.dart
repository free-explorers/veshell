import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shell/l10n/l10n.dart';

void main() {
  const autonyms = {
    'en': 'English',
    'ar': 'العربية',
    'bn': 'বাংলা',
    'de': 'Deutsch',
    'es': 'Español',
    'fr': 'Français',
    'hi': 'हिन्दी',
    'id': 'Bahasa Indonesia',
    'it': 'Italiano',
    'ja': '日本語',
    'ko': '한국어',
    'pl': 'Polski',
    'pt': 'Português',
    'pt_BR': 'Português (Brasil)',
    'pt_PT': 'Português (Portugal)',
    'ru': 'Русский',
    'tr': 'Türkçe',
    'ur': 'اردو',
    'vi': 'Tiếng Việt',
    'zh': '简体中文',
    'zh_Hant': '繁體中文',
  };

  test(
    'all shipped catalogs are complete and available in the language picker',
    () {
      final template =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;
      final keys = template.keys.where((key) => !key.startsWith('@')).toSet();
      expect(
        AppLocalizations.supportedLocales.map(
          (locale) => locale.toLanguageTag().replaceAll('-', '_'),
        ),
        unorderedEquals(autonyms.keys),
      );
      expect(AppLocalizations.supportedLocales.first, const Locale('en'));
      for (final entry in autonyms.entries) {
        final catalog =
            jsonDecode(File('lib/l10n/app_${entry.key}.arb').readAsStringSync())
                as Map<String, dynamic>;
        expect(catalog['@@locale'], entry.key);
        expect(
          catalog.keys.where((key) => !key.startsWith('@')).toSet(),
          keys,
          reason: '${entry.key} must not fall back to untranslated messages',
        );
        for (final key in keys) {
          expect(catalog[key], isA<String>());
          expect(catalog[key] as String, isNotEmpty);
          final metadata = template['@$key'] as Map<String, dynamic>?;
          final placeholders =
              metadata?['placeholders'] as Map<String, dynamic>?;
          for (final name in placeholders?.keys ?? <String>[]) {
            expect(
              (catalog[key] as String).contains('{$name}') ||
                  (catalog[key] as String).contains('{$name,'),
              isTrue,
              reason: '${entry.key}.$key must preserve placeholder $name',
            );
          }
        }
        final l10n = lookupAppLocalizations(_catalogLocale(entry.key));
        expect(l10n.languageAutonym, entry.value);
        expect(l10n.cannotOpenPath('/home/a {b}'), contains('/home/a {b}'));
        expect(l10n.requestsAttention('TestApp'), contains('TestApp'));
        expect(l10n.transformRotate(90), contains('90'));
        expect(
          l10n.monitorSettingChanged('SETTING', 'MONITOR'),
          allOf(contains('SETTING'), contains('MONITOR')),
        );
        for (final count in [0, 1, 2, 3, 5, 11, 21, 100]) {
          expect(l10n.itemCount(count), isNotEmpty);
          expect(l10n.minutesAgo(count), isNotEmpty);
          expect(l10n.hoursAgo(count), isNotEmpty);
          expect(l10n.daysAgo(count), isNotEmpty);
          expect(l10n.weeksAgo(count), isNotEmpty);
          expect(l10n.monthsAgo(count), isNotEmpty);
          expect(l10n.yearsAgo(count), isNotEmpty);
          expect(
            l10n.displaySettingsCountdown('DISPLAY', count),
            contains('DISPLAY'),
          );
        }
      }
    },
  );

  test('system locales select translations, with English as fallback', () {
    for (final language in autonyms.keys) {
      final locale = _catalogLocale(language);
      expect(
        resolveVeshellLocale([
          if (locale.countryCode == null && locale.scriptCode == null)
            Locale(locale.languageCode, 'XX')
          else
            locale,
        ], AppLocalizations.supportedLocales),
        locale,
      );
      expect(
        resolveVeshellLocale(
          const [Locale('en')],
          AppLocalizations.supportedLocales,
          preference: locale.toLanguageTag(),
        ),
        locale,
      );
    }
    expect(
      resolveVeshellLocale(const [
        Locale('zz'),
      ], AppLocalizations.supportedLocales),
      const Locale('en'),
    );
  });

  test(
    'Chinese script and regional preferences choose the correct catalog',
    () {
      for (final region in ['TW', 'HK', 'MO']) {
        final resolved = resolveVeshellLocale([
          Locale('zh', region),
        ], AppLocalizations.supportedLocales);
        expect(resolved, _catalogLocale('zh_Hant'));
        expect(lookupAppLocalizations(resolved).save, '儲存');
      }
      for (final region in ['CN', 'SG']) {
        final resolved = resolveVeshellLocale([
          Locale('zh', region),
        ], AppLocalizations.supportedLocales);
        expect(lookupAppLocalizations(resolved).save, '保存');
      }
      expect(
        resolveVeshellLocale(const [
          Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
            countryCode: 'TW',
          ),
        ], AppLocalizations.supportedLocales),
        const Locale('zh'),
      );
      expect(
        resolveVeshellLocale(
          const [Locale('en')],
          AppLocalizations.supportedLocales,
          preference: 'zh-Hant',
        ),
        _catalogLocale('zh_Hant'),
      );
    },
  );

  test('Portuguese regional catalogs use regional vocabulary', () {
    final brazil = lookupAppLocalizations(const Locale('pt', 'BR'));
    final portugal = lookupAppLocalizations(const Locale('pt', 'PT'));
    expect(brazil.save, 'Salvar');
    expect(portugal.save, 'Guardar');
    expect(brazil.password, 'Senha');
    expect(portugal.password, 'Palavra-passe');
  });

  test('Polish plural forms handle teens and compound counts', () {
    final l10n = lookupAppLocalizations(const Locale('pl'));
    expect(l10n.itemCount(1), '1 element');
    expect(l10n.itemCount(2), '2 elementy');
    expect(l10n.itemCount(5), '5 elementów');
    expect(l10n.itemCount(12), '12 elementów');
    expect(l10n.itemCount(22), '22 elementy');
    expect(l10n.itemCount(21), '21 elementów');
  });

  test('Russian plural forms follow the count, not just singular/plural', () {
    final l10n = lookupAppLocalizations(const Locale('ru'));
    expect(l10n.itemCount(1), '1 элемент');
    expect(l10n.itemCount(2), '2 элемента');
    expect(l10n.itemCount(5), '5 элементов');
    expect(l10n.itemCount(21), '21 элемент');
    expect(l10n.minutesAgo(21), '21 минуту назад');
  });

  test('zero-valued singular categories preserve the actual count', () {
    for (final language in ['fr', 'pt', 'hi', 'bn']) {
      final l10n = lookupAppLocalizations(Locale(language));
      expect(l10n.minutesAgo(0), contains(language == 'bn' ? '০' : '0'));
      expect(l10n.displaySettingsCountdown('DISPLAY', 0), contains('0'));
    }
  });

  test('Arabic includes zero, singular, dual, few and many forms', () {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    expect(l10n.itemCount(0), 'لا توجد عناصر');
    expect(l10n.itemCount(1), 'عنصر واحد');
    expect(l10n.itemCount(2), 'عنصران');
    expect(l10n.minutesAgo(2), 'قبل دقيقتين');
    expect(l10n.itemCount(3), contains('عناصر'));
    expect(l10n.itemCount(11), contains('عنصرًا'));
  });

  for (final language in autonyms.keys) {
    testWidgets(
      '$language loads app and Material translations with direction',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: _catalogLocale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                expect(
                  Directionality.of(context),
                  const {'ar', 'ur'}.contains(language)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                );
                expect(MaterialLocalizations.of(context), isNotNull);
                return Scaffold(body: Text(context.l10n.languageAutonym));
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(autonyms[language]!), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Locale _catalogLocale(String catalog) {
  final parts = catalog.split('_');
  return Locale.fromSubtags(
    languageCode: parts.first,
    scriptCode: parts.length > 1 && parts[1].length == 4 ? parts[1] : null,
    countryCode: parts.length > 1 && parts[1].length != 4 ? parts[1] : null,
  );
}
