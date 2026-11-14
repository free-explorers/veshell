import 'package:intl/intl.dart';
import 'package:shell/l10n/l10n.dart';

/// How the status bar writes the time. The enum names are the values
/// stored under `theme.statusBarContent.clockFormat`.
enum ClockFormat {
  /// The format of the shell's language. The default.
  locale,

  /// `h:mm AM`, whatever the language.
  twelveHour,

  /// `HH:mm`, whatever the language.
  twentyFourHour;

  DateFormat dateFormat(String locale) => switch (this) {
    ClockFormat.locale => DateFormat.jm(locale),
    ClockFormat.twelveHour => DateFormat('h:mm a', locale),
    ClockFormat.twentyFourHour => DateFormat.Hm(locale),
  };
}

/// The clock formats, in the order shown in the picker.
final List<String> clockFormatChoices = [
  for (final format in ClockFormat.values) format.name,
];

/// The localized label for a clock format setting string.
String clockFormatLabel(AppLocalizations l10n, String value) =>
    switch (ClockFormat.values.asNameMap()[value]) {
      ClockFormat.twelveHour => l10n.clockFormat12Hour,
      ClockFormat.twentyFourHour => l10n.clockFormat24Hour,
      _ => l10n.clockFormatLocale,
    };
