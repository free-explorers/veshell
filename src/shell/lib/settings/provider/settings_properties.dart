import 'dart:convert';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shell/l10n/l10n.dart';
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
import 'package:shell/settings/widget/locale/system_locale_editor.dart';
import 'package:shell/settings/widget/locale/veshell_language_editor.dart';
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
    final l10n = ref.watch(shellLocalizationsProvider);
    final monitors = ref.watch(connectedMonitorListProvider);
    return {
      'system': SettingGroup(
        name: l10n.languageAndRegion,
        description: null,
        icon: MdiIcons.translate,
        children: {
          'locale': SettingProperty<void>(
            name: l10n.systemLocale,
            description: l10n.systemLocaleDescription,
            buildSearchResult: (context, path, property) =>
                ExpandableSearchResult<void>(
                  path: path,
                  property: property,
                  buildValue: (context, value, {required isExpanded}) =>
                      const SystemLocaleValue(),
                  buildEditor: (context, {required isExpanded}) =>
                      const SystemLocaleEditor(),
                ),
          ),
          'language': SettingProperty<String>(
            name: l10n.veshellLanguage,
            description: l10n.veshellLanguageDescription,
            buildSearchResult: (context, path, property) =>
                ExpandableSearchResult<String>(
                  path: path,
                  property: property,
                  buildValue: (context, value, {required isExpanded}) =>
                      const VeshellLanguageValue(),
                  buildEditor: (context, {required isExpanded}) =>
                      const VeshellLanguageEditor(),
                ),
          ),
        },
      ),
      'monitors': SettingGroup(
        name: l10n.monitors,
        description: null,
        icon: MdiIcons.monitor,
        children: {
          // Arranging is only meaningful with more than one monitor.
          if (monitors.length > 1)
            'arrange': SettingProperty<void>(
              name: l10n.arrangeMonitors,
              description: l10n.arrangeMonitorsDescription,
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
                  name: l10n.resolution,
                  description: l10n.resolutionDescription,
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
                  name: l10n.refreshRate,
                  description: l10n.refreshRateDescription,
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
                'fractionnalScale': SettingProperty<double>(
                  name: l10n.fractionalScale,
                  description: l10n.fractionalScaleDescription,
                ),
                'transform': SettingProperty<MonitorTransform>(
                  name: l10n.transform,
                  description: l10n.transformDescription,
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
                  name: l10n.mirror,
                  description: l10n.mirrorDescription,
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
      'keyboard': SettingGroup(
        name: l10n.keyboard,
        description: null,
        icon: MdiIcons.keyboard,
        children: {
          'layout': SettingProperty<String>(
            name: l10n.layout,
            description: l10n.layoutDescription,
          ),
          'swapAltAndWin': SettingProperty<bool>(
            name: l10n.swapAltAndWin,
            description: l10n.swapAltAndWinDescription,
          ),
          'hotkeys': SettingGroup(
            name: l10n.hotkeys,
            description: l10n.hotkeysDescription,
            children: {
              'system.increaseVolume': SettingProperty<LogicalKeySet>(
                name: l10n.increaseVolume,
                description: l10n.increaseVolumeDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'system.decreaseVolume': SettingProperty<LogicalKeySet>(
                name: l10n.decreaseVolume,
                description: l10n.decreaseVolumeDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'system.muteVolume': SettingProperty<LogicalKeySet>(
                name: l10n.muteVolume,
                description: l10n.muteVolumeDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'system.increaseBrightness': SettingProperty<LogicalKeySet>(
                name: l10n.increaseBrightness,
                description: l10n.increaseBrightnessDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'system.decreaseBrightness': SettingProperty<LogicalKeySet>(
                name: l10n.decreaseBrightness,
                description: l10n.decreaseBrightnessDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'media.playPause': SettingProperty<LogicalKeySet>(
                name: l10n.playPauseMedia,
                description: l10n.playPauseMediaDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'media.next': SettingProperty<LogicalKeySet>(
                name: l10n.nextTrack,
                description: l10n.nextTrackDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'media.previous': SettingProperty<LogicalKeySet>(
                name: l10n.previousTrack,
                description: l10n.previousTrackDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'media.stop': SettingProperty<LogicalKeySet>(
                name: l10n.stopMedia,
                description: l10n.stopMediaDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'screen.focusWorkspaceAbove': SettingProperty<LogicalKeySet>(
                name: l10n.focusWorkspaceAbove,
                description: l10n.focusWorkspaceAboveDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'screen.focusWorkspaceBelow': SettingProperty<LogicalKeySet>(
                name: l10n.focusWorkspaceBelow,
                description: l10n.focusWorkspaceBelowDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'screen.reorderWorkspaceAbove': SettingProperty<LogicalKeySet>(
                name: l10n.moveWorkspaceUp,
                description: l10n.moveWorkspaceUpDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'screen.reorderWorkspaceBelow': SettingProperty<LogicalKeySet>(
                name: l10n.moveWorkspaceDown,
                description: l10n.moveWorkspaceDownDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'workspace.focusLeftTileable': SettingProperty<LogicalKeySet>(
                name: l10n.focusLeftTileable,
                description: l10n.focusLeftTileableDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'workspace.focusRightTileable': SettingProperty<LogicalKeySet>(
                name: l10n.focusRightTileable,
                description: l10n.focusRightTileableDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'workspace.reorderLeftTileable': SettingProperty<LogicalKeySet>(
                name: l10n.moveTileableLeft,
                description: l10n.moveTileableLeftDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'workspace.reorderRightTileable': SettingProperty<LogicalKeySet>(
                name: l10n.moveTileableRight,
                description: l10n.moveTileableRightDescription,
                converter: const LogicalKeySetConverter(),
              ),
              'workspace.closeTileable': SettingProperty<LogicalKeySet>(
                name: l10n.closeTileable,
                description: l10n.closeTileableDescription,
                converter: const LogicalKeySetConverter(),
              ),
            },
          ),
        },
      ),
      'mouseAndTouchpad': SettingGroup(
        name: l10n.mouseAndTouchpad,
        description: null,
        icon: MdiIcons.mouse,
        children: {
          'naturalScrolling': SettingProperty<bool>(
            name: l10n.naturalScrolling,
            description: l10n.naturalScrollingDescription,
          ),
        },
      ),
      'idle': SettingGroup(
        name: l10n.powerAndIdle,
        description: null,
        icon: MdiIcons.lightningBolt,
        children: {
          'dimTimeoutSeconds': SettingProperty<int>(
            name: l10n.dimAfter,
            description: l10n.dimAfterDescription,
          ),
          'blankTimeoutSeconds': SettingProperty<int>(
            name: l10n.blankAfter,
            description: l10n.blankAfterDescription,
          ),
          'fadeSeconds': SettingProperty<double>(
            name: l10n.dimFadeDuration,
            description: l10n.dimFadeDurationDescription,
          ),
          'automaticPowerAction': SettingProperty<String>(
            name: l10n.automaticPowerAction,
            description: l10n.automaticPowerActionDescription,
          ),
          'automaticPowerTimeoutSeconds': SettingProperty<int>(
            name: l10n.automaticPowerAfter,
            description: l10n.automaticPowerAfterDescription,
          ),
        },
      ),
      'notifications': SettingGroup(
        name: l10n.notifications,
        description: null,
        icon: MdiIcons.bell,
        children: {
          'batteryLowThreshold': SettingProperty<int>(
            name: l10n.lowBatteryWarning,
            description: l10n.lowBatteryWarningDescription,
          ),
          'batteryCriticalThreshold': SettingProperty<int>(
            name: l10n.criticalBatteryWarning,
            description: l10n.criticalBatteryWarningDescription,
          ),
        },
      ),
      'theme': SettingGroup(
        name: l10n.theme,
        description: null,
        icon: MdiIcons.palette,
        children: {
          'color': SettingProperty<Color>(
            name: l10n.color,
            description: l10n.colorDescription,
            converter: const ColorConverter(),
          ),
          'gtkTheme': SettingProperty<String>(
            name: l10n.gtkTheme,
            description: l10n.gtkThemeDescription,
          ),
          'iconTheme': SettingProperty<String>(
            name: l10n.iconTheme,
            description: l10n.iconThemeDescription,
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
    ref.read(configuredSettingsJsonProvider.notifier).publish(json);
  }
}
