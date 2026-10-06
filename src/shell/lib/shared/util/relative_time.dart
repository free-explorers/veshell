import 'package:flutter/widgets.dart';
import 'package:shell/l10n/l10n.dart';

/// Formats [dateTime] as a short, human-readable age for a notification header.
///
/// - under a minute: `Now`
/// - then minutes, hours, days, weeks, months, years, each pluralized and
///   suffixed with `ago` (e.g. `5 minutes ago`).
///
/// [localeName] selects the generated ARB messages and plural rules.
///
/// [now] is injectable so the result is deterministic in tests.
String formatRelativeTime(
  DateTime dateTime, {
  required String localeName,
  DateTime? now,
}) {
  final parts = localeName.replaceAll('-', '_').split('_');
  final l10n = lookupAppLocalizations(
    resolveVeshellLocale([
      Locale.fromSubtags(
        languageCode: parts.first,
        scriptCode: parts.length > 1 && parts[1].length == 4 ? parts[1] : null,
        countryCode: parts.length > 1 && parts.last.length != 4
            ? parts.last
            : null,
      ),
    ], AppLocalizations.supportedLocales),
  );
  final elapsed = (now ?? DateTime.now()).difference(dateTime);
  final seconds = elapsed.inSeconds;

  if (seconds < _minute) {
    return l10n.now;
  }
  if (seconds < _hour) {
    return l10n.minutesAgo(elapsed.inMinutes);
  }
  if (seconds < _day) {
    return l10n.hoursAgo(elapsed.inHours);
  }
  final days = elapsed.inDays;
  if (days < 7) {
    return l10n.daysAgo(days);
  }
  if (days < 35) {
    return l10n.weeksAgo(days ~/ 7);
  }
  if (days < 365) {
    return l10n.monthsAgo(days ~/ 30);
  }
  return l10n.yearsAgo(days ~/ 365);
}

const int _minute = 60;
const int _hour = 60 * _minute;
const int _day = 24 * _hour;
