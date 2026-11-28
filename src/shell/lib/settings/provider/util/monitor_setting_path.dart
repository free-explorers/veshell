/// The settings group holding every display setting: the arrangement, one
/// group per monitor, and the settings that apply to all of them.
const displaySettingsGroup = 'display';

/// The `display` settings that are not a monitor: everything else in the
/// group is keyed by a monitor's connector name (`eDP-1`, `HDMI-A-1`), which
/// never takes one of these names.
const displaySharedSettings = {'arrange', 'antialiasing', 'nightLight'};

/// A per-monitor setting path, `display.<monitor>.<property>`: its monitor and
/// the property path inside `monitor/<monitor>.json`.
typedef MonitorSettingPath = ({String monitor, String property});

/// Splits [path] when it names a monitor's own setting, or returns null for
/// any other path (`display.nightLight.from` is stored in `settings.json`).
MonitorSettingPath? parseMonitorSettingPath(String path) {
  final parts = path.split('.');
  if (parts.length < 3 ||
      parts.first != displaySettingsGroup ||
      displaySharedSettings.contains(parts[1])) {
    return null;
  }
  return (monitor: parts[1], property: parts.sublist(2).join('.'));
}
