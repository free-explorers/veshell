import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/provider/util/json_value_by_path.dart';
import 'package:shell/status_bar/model/clock_format.dart';
import 'package:shell/status_bar/model/status_bar_style.dart';

part 'status_bar_settings.g.dart';

const statusBarStylePath = 'theme.statusBar';
const statusBarShowClockPath = 'theme.statusBarContent.showClock';
const statusBarClockFormatPath = 'theme.statusBarContent.clockFormat';
const statusBarShowKeyboardLayoutPath =
    'theme.statusBarContent.showKeyboardLayout';
const statusBarShowWifiPath = 'theme.statusBarContent.showWifi';
const statusBarShowVolumePath = 'theme.statusBarContent.showVolume';
const statusBarShowBatteryPath = 'theme.statusBarContent.showBattery';
const statusBarShowBatteryPercentagePath =
    'theme.statusBarContent.showBatteryPercentage';

/// How the status bar is drawn, if at all, and what it shows.
typedef StatusBarSettings = ({
  StatusBarStyle style,
  bool showClock,
  ClockFormat clockFormat,
  bool showKeyboardLayout,
  bool showWifi,
  bool showVolume,
  bool showBattery,
  bool showBatteryPercentage,
});

extension StatusBarSettingsShown on StatusBarSettings {
  /// Whether the status bar is shown as the notch.
  bool get showsNotch => style == StatusBarStyle.notch;

  /// Whether the status bar is shown as the top panel.
  bool get showsTopPanel => style == StatusBarStyle.topPanel;
}

/// The status bar settings when nothing is stored: there is no status bar,
/// and every item it would hold is on.
const StatusBarSettings statusBarSettingsFallback = (
  style: StatusBarStyle.none,
  showClock: true,
  clockFormat: ClockFormat.locale,
  showKeyboardLayout: true,
  showWifi: true,
  showVolume: true,
  showBattery: true,
  showBatteryPercentage: true,
);

/// The persisted status bar preferences; a missing or malformed value falls
/// back to [statusBarSettingsFallback].
@riverpod
StatusBarSettings statusBarSettings(Ref ref) {
  bool readBool(String path, {required bool fallback}) {
    final value = ref.watch(jsonValueByPathProvider(path));
    return value is bool ? value : fallback;
  }

  T readEnum<T extends Enum>(String path, List<T> values, T fallback) =>
      values.asNameMap()[ref.watch(jsonValueByPathProvider(path))] ?? fallback;

  const fallback = statusBarSettingsFallback;
  return (
    style: readEnum(statusBarStylePath, StatusBarStyle.values, fallback.style),
    showClock: readBool(statusBarShowClockPath, fallback: fallback.showClock),
    clockFormat: readEnum(
      statusBarClockFormatPath,
      ClockFormat.values,
      fallback.clockFormat,
    ),
    showKeyboardLayout: readBool(
      statusBarShowKeyboardLayoutPath,
      fallback: fallback.showKeyboardLayout,
    ),
    showWifi: readBool(statusBarShowWifiPath, fallback: fallback.showWifi),
    showVolume: readBool(
      statusBarShowVolumePath,
      fallback: fallback.showVolume,
    ),
    showBattery: readBool(
      statusBarShowBatteryPath,
      fallback: fallback.showBattery,
    ),
    showBatteryPercentage: readBool(
      statusBarShowBatteryPercentagePath,
      fallback: fallback.showBatteryPercentage,
    ),
  );
}
