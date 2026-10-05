import 'dart:convert';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/monitor/model/monitor.serializable.dart';
import 'package:shell/monitor/provider/connected_monitor_list.dart';
import 'package:shell/monitor/widget/monitor_arrangement/monitor_arrangement_editor.dart';
import 'package:shell/settings/model/setting_group.dart';
import 'package:shell/settings/model/setting_property.dart';
import 'package:shell/settings/model/types/monitor_setting.serializable.dart';
import 'package:shell/settings/provider/state/monitor_setting_state.dart';
import 'package:shell/settings/provider/util/config_directory.dart';
import 'package:shell/settings/provider/util/configured_settings_json.dart';
import 'package:shell/settings/provider/util/default_settings_json.dart';
import 'package:shell/settings/widget/expandable_search_result.dart';
import 'package:shell/settings/widget/monitor/monitor_mirror_editor.dart';
import 'package:shell/settings/widget/monitor/monitor_mirror_value.dart';
import 'package:shell/settings/widget/monitor/monitor_refresh_rate_editor.dart';
import 'package:shell/settings/widget/monitor/monitor_refresh_rate_value.dart';
import 'package:shell/settings/widget/monitor/monitor_resolution_editor.dart';
import 'package:shell/settings/widget/monitor/monitor_resolution_value.dart';
import 'package:shell/settings/widget/monitor/monitor_transform_editor.dart';
import 'package:shell/settings/widget/monitor/monitor_transform_value.dart';
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
          // Arranging is only meaningful with more than one monitor.
          if (monitors.length > 1)
            'arrange': SettingProperty<void>(
              name: 'Arrange Monitors',
              description: 'Position monitors relative to each other',
              buildSearchResult: (context, path, property) =>
                  ExpandableSearchResult<void>(
                    path: path,
                    property: property,
                    buildValue: (context, value, {required isExpanded}) => Icon(
                      isExpanded ? MdiIcons.chevronUp : MdiIcons.chevronDown,
                    ),
                    buildEditor: (context, {required isExpanded}) =>
                        const MonitorArrangementEditor(),
                  ),
            ),
          for (final e in monitors)
            e.name: SettingGroup(
              name: e.name,
              description: e.description,
              children: {
                'resolution': SettingProperty<MonitorResolution>(
                  name: 'Resolution',
                  description: 'Monitor resolution',
                  buildSearchResult: (context, path, property) =>
                      ExpandableSearchResult(
                        path: path,
                        property: property,
                        buildValue: (context, value, {required isExpanded}) =>
                            MonitorResolutionValue(path: path),
                        buildEditor: (context, {required isExpanded}) =>
                            MonitorResolutionEditor(
                              path: path,
                              property: property,
                            ),
                      ),
                ),
                'refreshRate': SettingProperty<MonitorRefreshRate>(
                  name: 'Refresh Rate',
                  description: 'Monitor refresh rate',
                  buildSearchResult: (context, path, property) =>
                      ExpandableSearchResult(
                        path: path,
                        property: property,
                        buildValue: (context, value, {required isExpanded}) =>
                            MonitorRefreshRateValue(path: path),
                        buildEditor: (context, {required isExpanded}) =>
                            MonitorRefreshRateEditor(
                              path: path,
                              property: property,
                            ),
                      ),
                ),
                'fractionnalScale': const SettingProperty<double>(
                  name: 'Fractionnal Scale',
                  description: 'Monitor fractionnal scaling',
                ),
                'transform': SettingProperty<MonitorTransform>(
                  name: 'Transform',
                  description: 'Display rotation and mirroring',
                  buildSearchResult: (context, path, property) =>
                      ExpandableSearchResult<MonitorTransform>(
                        path: path,
                        property: property,
                        buildValue: (context, value, {required isExpanded}) =>
                            MonitorTransformValue(path: path),
                        buildEditor: (context, {required isExpanded}) =>
                            MonitorTransformEditor(
                              path: path,
                              property: property,
                            ),
                      ),
                ),
                'mirrorOf': SettingProperty<String?>(
                  name: 'Mirror',
                  description: 'Mirror another monitor on this one',
                  buildSearchResult: (context, path, property) =>
                      ExpandableSearchResult<String?>(
                        path: path,
                        property: property,
                        buildValue: (context, value, {required isExpanded}) =>
                            MonitorMirrorValue(path: path),
                        buildEditor: (context, {required isExpanded}) =>
                            MonitorMirrorEditor(path: path, property: property),
                      ),
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
          'swapAltAndWin': SettingProperty<bool>(
            name: 'Swap Alt and Win',
            description:
                'Improve thumb ergonomics by swapping the Alt and Win keys',
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
              'system.increaseBrightness': SettingProperty<LogicalKeySet>(
                name: 'Increase Brightness',
                description: 'Increase the display brightness',
                converter: LogicalKeySetConverter(),
              ),
              'system.decreaseBrightness': SettingProperty<LogicalKeySet>(
                name: 'Decrease Brightness',
                description: 'Decrease the display brightness',
                converter: LogicalKeySetConverter(),
              ),
              'media.playPause': SettingProperty<LogicalKeySet>(
                name: 'Play/Pause Media',
                description: 'Toggle playback of the active media player',
                converter: LogicalKeySetConverter(),
              ),
              'media.next': SettingProperty<LogicalKeySet>(
                name: 'Next Track',
                description: 'Skip to the next track',
                converter: LogicalKeySetConverter(),
              ),
              'media.previous': SettingProperty<LogicalKeySet>(
                name: 'Previous Track',
                description: 'Go back to the previous track',
                converter: LogicalKeySetConverter(),
              ),
              'media.stop': SettingProperty<LogicalKeySet>(
                name: 'Stop Media',
                description: 'Stop the active media player',
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
              'screen.reorderWorkspaceAbove': SettingProperty<LogicalKeySet>(
                name: 'Move Workspace Up',
                description: 'Move the current workspace up',
                converter: LogicalKeySetConverter(),
              ),
              'screen.reorderWorkspaceBelow': SettingProperty<LogicalKeySet>(
                name: 'Move Workspace Down',
                description: 'Move the current workspace down',
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
              'workspace.reorderLeftTileable': SettingProperty<LogicalKeySet>(
                name: 'Move Tileable Left',
                description: 'Move the current tileable to the left',
                converter: LogicalKeySetConverter(),
              ),
              'workspace.reorderRightTileable': SettingProperty<LogicalKeySet>(
                name: 'Move Tileable Right',
                description: 'Move the current tileable to the right',
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
      'mouseAndTouchpad': const SettingGroup(
        name: 'Mouse and Touchpad',
        description: null,
        icon: MdiIcons.mouse,
        children: {
          'naturalScrolling': SettingProperty<bool>(
            name: 'Natural Scrolling',
            description:
                'Toggle Natural scrolling (reversed scrolling direction)',
          ),
        },
      ),
      'idle': const SettingGroup(
        name: 'Power and Idle',
        description: null,
        icon: MdiIcons.lightningBolt,
        children: {
          'dimTimeoutSeconds': SettingProperty<int>(
            name: 'Dim After (seconds)',
            description: 'Set to 0 to disable idle dimming',
          ),
          'blankTimeoutSeconds': SettingProperty<int>(
            name: 'Blank After (seconds)',
            description: 'Set to 0 to disable display blanking',
          ),
          'fadeSeconds': SettingProperty<double>(
            name: 'Dim Fade Duration (seconds)',
            description: 'Duration of the transition to the dimmed screen',
          ),
          'automaticPowerAction': SettingProperty<String>(
            name: 'Automatic Power Action',
            description:
                'suspendThenHibernate uses logind when available, otherwise it suspends',
          ),
          'automaticPowerTimeoutSeconds': SettingProperty<int>(
            name: 'Automatic Power After (seconds)',
            description:
                'Default is 600 seconds; set to 0 to disable automatic sleep or hibernate',
          ),
        },
      ),
      'notifications': const SettingGroup(
        name: 'Notifications',
        description: null,
        icon: MdiIcons.bell,
        children: {
          'batteryLowThreshold': SettingProperty<int>(
            name: 'Low Battery Warning (%)',
            description:
                'Show a warning when the battery drains to this percentage',
          ),
          'batteryCriticalThreshold': SettingProperty<int>(
            name: 'Critical Battery Warning (%)',
            description:
                'Show a persistent warning when the battery drains to this percentage',
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

  void updateProperty(String path, dynamic newValue) {
    final parts = path.split('.');
    if (parts.first == 'monitors') {
      return ref
          .read(monitorSettingStateProvider(parts[1]).notifier)
          .updateByPath(parts.sublist(2).join('.'), newValue);
    }

    final defaultJson = ref.read(defaultSettingsJsonProvider);
    final json = ref.read(configuredSettingsJsonProvider);
    final configDirectory = ref.read(configDirectoryProvider);

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
