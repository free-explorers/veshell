import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shell/l10n/app_localizations.dart';
import 'package:shell/settings/provider/util/configured_settings_json.dart';

export 'package:shell/l10n/app_localizations.dart';

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
  return basicLocaleListResolution(system, supported);
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
