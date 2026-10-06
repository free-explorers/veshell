import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:shell/l10n/app_localizations.dart';
import 'package:shell/settings/provider/util/configured_settings_json.dart';

export 'package:shell/l10n/app_localizations.dart';

/// The UI packages define distinct Material/Cupertino localization types.
/// Keep Flutter's delegates too: SDK widgets and package widgets can coexist.
const shellLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  ...AppLocalizations.localizationsDelegates,
  ...material_ui.GlobalMaterialLocalizations.delegates,
];

/// The session's preferred locales, before any Veshell-only fallback choice.
final systemLocalesProvider = NotifierProvider<SystemLocales, List<Locale>>(
  SystemLocales.new,
);

/// Latest successfully read/saved locale1 preferences. Keep these separate
/// from the running session's environment (used for desktop-entry metadata).
final configuredSystemLocalesProvider =
    NotifierProvider<ConfiguredSystemLocales, List<Locale>?>(
      ConfiguredSystemLocales.new,
    );

class ConfiguredSystemLocales extends Notifier<List<Locale>?> {
  @override
  List<Locale>? build() {
    // A real platform locale update supersedes our in-session snapshot.
    ref.watch(systemLocalesProvider);
    return null;
  }

  void update(List<Locale> locales) => state = List.unmodifiable(locales);
}

final veshellLocalePreferencesProvider = Provider<List<Locale>>(
  (ref) =>
      ref.watch(configuredSystemLocalesProvider) ??
      ref.watch(systemLocalesProvider),
);

/// Regional variants can use a language's catalog, but explicitly different
/// scripts should not be treated as the same translation.
bool hasSupportedSystemLanguage(List<Locale> system, List<Locale> supported) =>
    system.any(
      (locale) => supported.any(
        (candidate) =>
            locale.languageCode == candidate.languageCode &&
            (locale.scriptCode == null ||
                candidate.scriptCode == null ||
                locale.scriptCode == candidate.scriptCode),
      ),
    );

final systemLanguageSupportedProvider = Provider<bool>(
  (ref) => hasSupportedSystemLanguage(
    ref.watch(veshellLocalePreferencesProvider),
    AppLocalizations.supportedLocales,
  ),
);

/// The app root connects persistence; standalone widgets/providers default to
/// following the system without requiring filesystem configuration.
final veshellLanguagePreferenceProvider = Provider<String?>((ref) => null);

String? configuredVeshellLanguagePreference(Ref ref) {
  final system = ref.watch(configuredSettingsJsonProvider)['system'];
  final language = system is Map ? system['language'] : null;
  return language is String ? language : null;
}

final veshellFollowsSystemProvider = Provider<bool>((ref) {
  final preference = ref.watch(veshellLanguagePreferenceProvider);
  final hasOverride = AppLocalizations.supportedLocales.any(
    (locale) => locale.toLanguageTag() == preference,
  );
  return !hasOverride && ref.watch(systemLanguageSupportedProvider);
});

Locale resolveVeshellLocale(
  List<Locale> system,
  List<Locale> supported, {
  String? preference,
}) {
  for (final locale in supported) {
    if (locale.toLanguageTag() == preference) return locale;
  }
  return basicLocaleListResolution([
    for (final locale in system)
      // Linux locales often specify a Chinese region without a script.
      // Do not resolve Taiwan/Hong Kong/Macao to the Simplified catalog.
      if (locale.languageCode == 'zh' &&
          locale.scriptCode == null &&
          const {'TW', 'HK', 'MO'}.contains(locale.countryCode))
        Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: locale.countryCode,
        )
      else
        locale,
  ], supported);
}

final shellLocaleProvider = Provider<Locale>((ref) {
  final system = ref.watch(veshellLocalePreferencesProvider);
  const supported = AppLocalizations.supportedLocales;
  return resolveVeshellLocale(
    system,
    supported,
    preference: ref.watch(veshellLanguagePreferenceProvider),
  );
});

class SystemLocales extends Notifier<List<Locale>> with WidgetsBindingObserver {
  @override
  List<Locale> build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return WidgetsBinding.instance.platformDispatcher.locales;
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    state = locales ?? const [];
  }
}

final shellLocalizationsProvider = Provider<AppLocalizations>(
  (ref) => lookupAppLocalizations(ref.watch(shellLocaleProvider)),
);

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String measurement(num value, String unit, {int decimalDigits = 0}) =>
      l10n.valueWithUnit(
        NumberFormat.decimalPatternDigits(
          locale: l10n.localeName,
          decimalDigits: decimalDigits,
        ).format(value),
        unit,
      );
}
