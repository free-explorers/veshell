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

  test('lists matching categories in display order', () {
    expect(collectSettingCategoryPathList(settingMap, ''), [
      'display',
      'power',
    ]);
  });

  test('keeps a category only when a descendant matches', () {
    expect(collectSettingCategoryPathList(settingMap, 'night'), ['display']);
    expect(collectSettingCategoryPathList(settingMap, 'idle dim'), ['power']);
  });

  test('returns nothing when no category matches', () {
    expect(collectSettingCategoryPathList(settingMap, 'zzz'), isEmpty);
  });
}
