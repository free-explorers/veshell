import 'package:flutter/widgets.dart';

/// Variables supported by the system locale editor. Serialized names belong to
/// locale1 and must not be translated.
const systemLocaleVariables = [
  'LANG',
  'LC_MESSAGES',
  'LC_CTYPE',
  'LC_NUMERIC',
  'LC_TIME',
  'LC_COLLATE',
  'LC_MONETARY',
  'LC_PAPER',
  'LC_NAME',
  'LC_ADDRESS',
  'LC_TELEPHONE',
  'LC_MEASUREMENT',
  'LC_IDENTIFICATION',
];

/// glibc's `locale -a` commonly reports `.utf8`, while locale.conf uses UTF-8.
String canonicalSystemLocale(String value) => value.trim().replaceFirst(
  RegExp(r'\.utf-?8(?=@|$)', caseSensitive: false),
  '.UTF-8',
);

/// Hide encoding variants, but keep modifiers such as @latin distinct.
String systemLocaleName(String value) =>
    canonicalSystemLocale(value).replaceFirst(RegExp(r'\.[^@]+'), '');

/// One installed value per locale, preferring UTF-8 without inventing locales.
Map<String, String> preferredSystemLocales(Iterable<String> installed) {
  final variants = installed.map(canonicalSystemLocale).toSet().toList()
    ..sort();
  final choices = <String, String>{};
  for (final locale in variants) {
    final name = systemLocaleName(locale);
    if (!choices.containsKey(name) ||
        RegExp(r'\.UTF-8(?:@|$)').hasMatch(locale)) {
      choices[name] = locale;
    }
  }
  return Map.unmodifiable(choices);
}

List<String> parseInstalledSystemLocales(String output) {
  final valid = RegExp(r'^[A-Za-z][A-Za-z0-9_]*(?:[.@-][A-Za-z0-9_-]+)*$');
  final locales = {
    'C',
    'POSIX',
    for (final line in output.split('\n'))
      if (valid.hasMatch(line.trim())) canonicalSystemLocale(line),
  }.toList()..sort();
  return List.unmodifiable(locales);
}

Map<String, String> parseSystemLocaleAssignments(Iterable<String> assignments) {
  final values = <String, String>{};
  for (final assignment in assignments) {
    final separator = assignment.indexOf('=');
    if (separator > 0) {
      values[assignment.substring(0, separator)] = assignment.substring(
        separator + 1,
      );
    }
  }
  return Map.unmodifiable(values);
}

/// Message preferences for the newly configured system, not the old session
/// environment. Mirrors the embedder's Linux locale parsing and precedence.
List<Locale> systemMessageLocales(Map<String, String> configuration) {
  Locale? parse(String value) {
    final pieces = value.trim().split('@');
    final base = pieces.first.split('.').first;
    if (base == 'C' || base == 'POSIX') return const Locale('en', 'US');
    final parts = base.split(RegExp('[_-]'));
    if (!RegExp(r'^[A-Za-z]{2,3}$').hasMatch(parts.first)) return null;
    var script = switch (pieces.length > 1 ? pieces[1] : '') {
      'latin' => 'Latn',
      'cyrillic' => 'Cyrl',
      _ => null,
    };
    String? country;
    for (final part in parts.skip(1)) {
      if (RegExp(r'^[A-Za-z]{4}$').hasMatch(part)) {
        script = '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      } else if (RegExp(r'^(?:[A-Za-z]{2}|[0-9]{3})$').hasMatch(part)) {
        country = part.toUpperCase();
      } else {
        return null;
      }
    }
    return Locale.fromSubtags(
      languageCode: parts.first.toLowerCase(),
      scriptCode: script,
      countryCode: country,
    );
  }

  final message =
      ['LC_ALL', 'LC_MESSAGES', 'LANG']
          .map((key) => configuration[key]?.trim())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .firstOrNull ??
      'C';
  final isC = ['C', 'POSIX'].contains(message.split('.').first);
  final locales = <Locale>{
    if (!isC)
      for (final value in (configuration['LANGUAGE'] ?? '').split(':'))
        if (parse(value) case final Locale locale) locale,
    if (parse(message) case final Locale locale) locale,
  };
  return List.unmodifiable(
    locales.isEmpty ? [const Locale('en', 'US')] : locales,
  );
}

/// Merge edits into the full locale1 configuration: SetLocale replaces all
/// assignments, so sending just LANG would silently erase regional overrides.
Map<String, String> applySystemLocaleChanges(
  Map<String, String> current,
  Map<String, String?> changes,
  List<String> installed,
) {
  final available = installed.map(canonicalSystemLocale).toSet();
  final next = Map<String, String>.of(current);
  for (final entry in changes.entries) {
    if (!systemLocaleVariables.contains(entry.key)) {
      throw ArgumentError.value(
        entry.key,
        'variable',
        'Unsupported locale variable',
      );
    }
    final value = entry.value;
    if (value == null) {
      next.remove(entry.key);
    } else {
      final locale = canonicalSystemLocale(value);
      if (!available.contains(locale)) {
        throw ArgumentError.value(value, 'locale', 'Locale is not installed');
      }
      next[entry.key] = locale;
    }
  }
  return Map.unmodifiable(next);
}

/// Another settings client changed locale1 while the user was editing.
class SystemLocaleConflict implements Exception {}
