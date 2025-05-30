import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/provider/util/config_directory.dart';
import 'package:shell/settings/provider/util/configured_settings_json.dart';
import 'package:shell/settings/provider/util/default_settings_json.dart';
import 'package:shell/shared/util/file.dart';
import 'package:shell/shared/util/json_converter/color.dart';
import 'package:shell/shared/util/json_converter/logical_key_set.dart';

part 'settings_properties.g.dart';

@riverpod
class SettingsProperties extends _$SettingsProperties {
  @override
  Map<String, SettingGroup> build() {
    final monitors = ref.watch(connectedMonitorListProvider);
    return {
      'monitors': SettingGroup(
        name: 'Monitors',
        description: null,
        icon: MdiIcons.monitor,
        children: {
          for (final e in monitors)
            e.name: SettingGroup(
              name: e.name,
              description: e.description,
              children: {
                'resolution': const SettingProperty<MonitorResolution>(
                  name: 'Resolution',
                  description: 'Monitor resolution',
                ),
                'refreshRate': const SettingProperty<MonitorRefreshRate>(
                  name: 'Refresh Rate',
                  description: 'Monitor refresh rate',
                ),
              },
            ),
        },
      ),
      'keyboard': const SettingGroup(
        name: 'Keyboard',
        description: null,
        icon: MdiIcons.keyboard,
        children: {
          'layout': SettingProperty<String>(
            name: 'Layout',
            description: 'Keyboard layout',
          ),
          'hotkeys': SettingGroup(
            name: 'Hotkeys',
            description: 'Hotkeys settings',
            children: {
              'system.increaseVolume': SettingProperty<LogicalKeySet>(
                name: 'Increase Volume',
                description: 'Increase the volume',
                converter: LogicalKeySetConverter(),
              ),
              'system.decreaseVolume': SettingProperty<LogicalKeySet>(
                name: 'Decrease Volume',
                description: 'Decrease the volume',
                converter: LogicalKeySetConverter(),
              ),
              'system.muteVolume': SettingProperty<LogicalKeySet>(
                name: 'Mute Volume',
                description: 'Toggle Mute volume',
                converter: LogicalKeySetConverter(),
              ),
              'screen.focusWorkspaceAbove': SettingProperty<LogicalKeySet>(
                name: 'Focus Workspace Above',
                description: 'Focus workspace above',
                converter: LogicalKeySetConverter(),
              ),
              'screen.focusWorkspaceBelow': SettingProperty<LogicalKeySet>(
                name: 'Focus Workspace Below',
                description: 'Focus workspace below',
                converter: LogicalKeySetConverter(),
              ),
              'workspace.focusLeftTileable': SettingProperty<LogicalKeySet>(
                name: 'Focus Left Tileable',
                description: 'Focus the next tileable on the left',
                converter: LogicalKeySetConverter(),
              ),
              'workspace.focusRightTileable': SettingProperty<LogicalKeySet>(
                name: 'Focus Right Tileable',
                description: 'Focus the next tileable on the right',
                converter: LogicalKeySetConverter(),
              ),
              'workspace.closeTileable': SettingProperty<LogicalKeySet>(
                name: 'Close Tileable',
                description: 'Close the currently focused tileable',
                converter: LogicalKeySetConverter(),
              ),
            },
          ),
        },
      ),
      'theme': const SettingGroup(
        name: 'Theme',
        description: null,
        icon: MdiIcons.palette,
        children: {
          'color': SettingProperty<Color>(
            name: 'Color',
            description: 'Theme color',
            converter: ColorConverter(),
          ),
          'gtkTheme': SettingProperty<String>(
            name: 'GTK Theme',
            description: 'GTK theme',
          ),
          'iconTheme': SettingProperty<String>(
            name: 'Icon Theme',
            description: 'Icon theme',
          ),
        },
      ),
    };
  }

  void updateProperty(String path, String? newValue) {
    final defaultJson = ref.read(defaultSettingsJsonProvider);
    final json = ref.read(configuredSettingsJsonProvider);
    final configDirectory = ref.read(configDirectoryProvider);

    final parts = path.split('.');
    var currentMap = json;
    var defaultCurrentMap = defaultJson;

    for (var i = 0; i < parts.length - 1; i++) {
      final key = parts[i];
      if (!currentMap.containsKey(key) || currentMap[key] is! Map) {
        currentMap[key] = <String, dynamic>{};
      }
      currentMap = currentMap[key] as Map<String, dynamic>;

      if (!defaultCurrentMap.containsKey(key) ||
          defaultCurrentMap[key] is! Map) {
        throw Exception('Invalid path: $path');
      }
      defaultCurrentMap = defaultCurrentMap[key] as Map<String, dynamic>;
    }

    final lastKey = parts.last;
    final defaultValue = defaultCurrentMap[lastKey];

    if (newValue == null || newValue == defaultValue) {
      currentMap.remove(lastKey);
    } else {
      currentMap[lastKey] = newValue;
    }

    // Clean currentMap removing any nested map without any property
    void cleanMap(Map<String, dynamic> map) {
      map.removeWhere((key, value) {
        if (value is Map) {
          cleanMap(value as Map<String, dynamic>);
          return value.isEmpty;
        }
        return false;
      });
    }

    cleanMap(json);

    // Write the updated JSON back to the file with indentation
    const encoder = JsonEncoder.withIndent('  ');
    writeFileAtomically(
      '${configDirectory.path}/settings.json',
      encoder.convert(json),
    );
  }
}
