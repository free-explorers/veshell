import 'dart:ui';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/shared/util/json_converter/color.dart';

part 'settings_properties.g.dart';

@riverpod
Map<String, Map<String, dynamic>> settingsProperties(Ref ref) {
  return {
    'keyboard': {
      'layout': const SettingProperty<String>(
        name: 'Layout',
        description: 'Keyboard layout',
      ),
    },
    'theme': {
      'color': const SettingProperty<Color>(
        name: 'Color',
        description: 'Theme color',
        converter: ColorConverter(),
      ),
      'gtkTheme': const SettingProperty<String>(
        name: 'GTK Theme',
        description: 'GTK theme',
      ),
      'iconTheme': const SettingProperty<String>(
        name: 'Icon Theme',
        description: 'Icon theme',
      ),
    },
  };
}
