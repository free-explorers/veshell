import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shell/l10n/l10n.dart';
import 'package:shell/settings/provider/state/night_light_setting.dart';

/// Night Light schedule choices, as stored in `display.nightLight.schedule`.
const nightLightSchedules = <String>['off', 'manual'];

/// The localized label for a Night Light schedule.
String nightLightScheduleLabel(AppLocalizations l10n, String value) =>
    switch (value) {
      'manual' => l10n.nightLightScheduleManual,
      _ => l10n.nightLightScheduleOff,
    };

/// The times the schedule's start and end are picked from: every half hour.
/// A hand-edited time between them still works; the picker then shows the
/// default as checked.
final List<String> nightLightTimes = [
  for (var minutes = 0; minutes < 24 * 60; minutes += 30)
    serializeTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60)),
];

/// A stored `HH:MM` time in the locale's clock format.
String nightLightTimeLabel(AppLocalizations l10n, String value) {
  final time = parseTimeOfDay(value);
  if (time == null) return value;
  return formatNightLightTime(l10n.localeName, time.hour, time.minute);
}

/// [hour]:[minute] in [locale]'s clock format.
String formatNightLightTime(String locale, int hour, int minute) =>
    DateFormat.jm(locale).format(DateTime(2000, 1, 1, hour, minute));
