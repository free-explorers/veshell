import 'package:flutter_test/flutter_test.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/model/setting_search.dart';

void main() {
  const settingMap = <String, SettingGroup>{
    'display': SettingGroup(
      name: 'Display',
      description: null,
      children: {
        'brightness': SettingProperty<int>(
          name: 'Brightness',
          description: 'Screen brightness',
        ),
        'nightLight': SettingProperty<bool>(
          name: 'Night Light',
          description: 'Warm colors at night',
        ),
      },
    ),
    'power': SettingGroup(
      name: 'Power',
      description: null,
      children: {
        'dim': SettingProperty<int>(
          name: 'Dim After',
          description: 'Idle dim timeout',
        ),
      },
    ),
  };

  test('lists every leaf in tree order for an empty search', () {
    expect(collectSettingLeafPathList(settingMap, ''), [
      'display.brightness',
      'display.nightLight',
      'power.dim',
    ]);
  });

  test('keeps only matching leaves', () {
    expect(collectSettingLeafPathList(settingMap, 'night'), [
      'display.nightLight',
    ]);
  });

  test('matches on the description too', () {
    expect(collectSettingLeafPathList(settingMap, 'idle dim'), ['power.dim']);
  });

  test('returns nothing when no leaf matches', () {
    expect(collectSettingLeafPathList(settingMap, 'zzz'), isEmpty);
  });
}
