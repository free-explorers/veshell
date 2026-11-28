import 'package:flutter_test/flutter_test.dart';
import 'package:shell/settings/provider/state/night_light_setting.dart';
import 'package:shell/settings/provider/util/monitor_setting_path.dart';

void main() {
  test('a monitor setting is routed to its monitor file', () {
    expect(parseMonitorSettingPath('display.eDP-1.resolution'), (
      monitor: 'eDP-1',
      property: 'resolution',
    ));
    expect(parseMonitorSettingPath('display.HDMI-A-1.location.x'), (
      monitor: 'HDMI-A-1',
      property: 'location.x',
    ));
  });

  test('the shared display settings stay in settings.json', () {
    for (final path in [
      'display.arrange',
      'display.antialiasing',
      nightLightSchedulePath,
      nightLightFromPath,
      nightLightToPath,
      nightLightTemperaturePath,
    ]) {
      expect(parseMonitorSettingPath(path), isNull, reason: path);
    }
  });

  test('other groups are not monitors', () {
    expect(parseMonitorSettingPath('theme.statusBar'), isNull);
    expect(
      parseMonitorSettingPath('keyboard.hotkeys.system.lockSession'),
      isNull,
    );
    // The group's old name is gone.
    expect(parseMonitorSettingPath('monitors.eDP-1.resolution'), isNull);
  });

  test('Night Light is stored under display', () {
    expect(nightLightSchedulePath, startsWith('$displaySettingsGroup.'));
  });
}
