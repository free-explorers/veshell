import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';

part 'night_light_setting.g.dart';

const nightLightSchedulePath = 'display.nightLight.schedule';
const nightLightFromPath = 'display.nightLight.from';
const nightLightToPath = 'display.nightLight.to';
const nightLightTemperaturePath = 'display.nightLight.temperature';

/// Defaults mirror `extra/settings/default/settings.json` and the compositor's
/// `NightLightSettings`.
const nightLightScheduleFallback = 'off';
const nightLightFromFallback = TimeOfDay(hour: 20, minute: 0);
const nightLightToFallback = TimeOfDay(hour: 6, minute: 0);
const nightLightTemperatureFallback = 2700;

/// The temperature range the compositor supports, in kelvin.
const nightLightMinTemperature = 1700;
const nightLightMaxTemperature = 6500;

/// Night Light's schedule, as the Helm describes it: whether it follows the
/// daily window, and the window.
typedef NightLightSchedule = ({bool scheduled, TimeOfDay from, TimeOfDay to});

/// The stored schedule; a missing or malformed value falls back to the
/// defaults, as the compositor does.
@riverpod
NightLightSchedule nightLightSchedule(Ref ref) {
  final schedule = ref.watch(jsonValueByPathProvider(nightLightSchedulePath));
  return (
    scheduled: schedule == 'manual',
    from:
        parseTimeOfDay(
          ref.watch(jsonValueByPathProvider(nightLightFromPath)),
        ) ??
        nightLightFromFallback,
    to:
        parseTimeOfDay(ref.watch(jsonValueByPathProvider(nightLightToPath))) ??
        nightLightToFallback,
  );
}

/// Parses a stored `HH:MM` time (24-hour clock), or null when malformed.
TimeOfDay? parseTimeOfDay(Object? value) {
  if (value is! String) return null;
  final parts = value.trim().split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// Formats a time as stored: `HH:MM`, 24-hour clock.
String serializeTimeOfDay(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
