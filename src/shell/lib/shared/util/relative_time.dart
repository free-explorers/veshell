import 'package:intl/intl.dart';

/// Formats [dateTime] as a short, human-readable age for a notification header.
///
/// - under a minute: `Now`
/// - then minutes, hours, days, weeks, months, years, each pluralized and
///   suffixed with `ago` (e.g. `5 minutes ago`).
///
/// [localeName] is a BCP-47 tag — call it with
/// `Localizations.localeOf(context).toString()` — and is handed to `intl` so
/// the plural category is selected for the reader's language. The English
/// strings are still inline: when app-wide localization (ARB catalogs) lands,
/// move them into `AppLocalizations` and read them from here; the call sites do
/// not change.
///
/// [now] is injectable so the result is deterministic in tests.
String formatRelativeTime(
  DateTime dateTime, {
  required String localeName,
  DateTime? now,
}) {
  final elapsed = (now ?? DateTime.now()).difference(dateTime);
  final seconds = elapsed.inSeconds;

  if (seconds < _minute) {
    return 'Now';
  }
  if (seconds < _hour) {
    return _plural(elapsed.inMinutes, 'minute', localeName);
  }
  if (seconds < _day) {
    return _plural(elapsed.inHours, 'hour', localeName);
  }
  final days = elapsed.inDays;
  if (days < 7) {
    return _plural(days, 'day', localeName);
  }
  if (days < 35) {
    return _plural(days ~/ 7, 'week', localeName);
  }
  if (days < 365) {
    return _plural(days ~/ 30, 'month', localeName);
  }
  return _plural(days ~/ 365, 'year', localeName);
}

/// `1 <unit> ago` / `N <unit>s ago`, pluralized for [localeName].
String _plural(int count, String unit, String localeName) => Intl.plural(
      count,
      one: '1 $unit ago',
      other: '$count ${unit}s ago',
      locale: localeName,
    );

const int _minute = 60;
const int _hour = 60 * _minute;
const int _day = 24 * _hour;
