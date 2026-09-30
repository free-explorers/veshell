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

  test('lists only the top-level categories while nothing is expanded', () {
    final rows = collectSettingVisibleRowList(settingMap, '', {});
    expect(rows.map((row) => row.path), ['display', 'power']);
    expect(rows.every((row) => row.isGroup), isTrue);
  });

  test('an expanded category contributes its children after its header', () {
    final rows = collectSettingVisibleRowList(settingMap, '', {'display'});
    expect(rows.map((row) => row.path), [
      'display',
      'display.brightness',
      'display.nightLight',
      'power',
    ]);
    expect(rows[1].isGroup, isFalse);
  });

  test('filtering force-opens the matching groups', () {
    final rows = collectSettingVisibleRowList(settingMap, 'night', {});
    expect(rows.map((row) => row.path), ['display', 'display.nightLight']);
  });

  test('returns nothing when no row matches', () {
    expect(collectSettingVisibleRowList(settingMap, 'zzz', {}), isEmpty);
  });
}
